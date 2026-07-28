# server/app/auth.py
#
# 구글/카카오 로그인 + 자체 JWT 발급.
# 흐름: 클라이언트가 구글/카카오 SDK로 토큰을 받아온다
#      → 이 서버가 그 토큰을 각 provider에 검증 요청
#      → users 테이블에서 (provider, provider_user_id)로 조회, 없으면 새로 생성
#      → access token(JWT, 30분) + refresh token(랜덤 문자열, DB엔 해시만 저장, 30일) 발급
#
# 인증/DB 부분만 담당 — 요약/퀴즈(main.py)와는 독립적인 라우터.
import asyncio
import os
from datetime import datetime, timezone

import httpx
from fastapi import APIRouter, Depends, HTTPException
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .database import get_db
from .models import RefreshToken, User
from .security import create_access_token, generate_refresh_token, hash_token

router = APIRouter(prefix="/auth", tags=["auth"])

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")


# ── 요청/응답 스키마 ─────────────────────────────────────────────
class GoogleLoginRequest(BaseModel):
    id_token: str


class KakaoLoginRequest(BaseModel):
    access_token: str


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    provider: str
    email: str | None
    nickname: str
    profile_image_url: str | None


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserOut


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str


# ── 공통 로직 ────────────────────────────────────────────────────
async def _find_or_create_user(
    db: AsyncSession,
    provider: str,
    provider_user_id: str,
    email: str | None,
    nickname: str,
    profile_image_url: str | None,
) -> User:
    result = await db.execute(
        select(User).where(User.provider == provider, User.provider_user_id == provider_user_id)
    )
    user = result.scalar_one_or_none()
    if user is None:
        user = User(
            provider=provider,
            provider_user_id=provider_user_id,
            email=email,
            nickname=nickname,
            profile_image_url=profile_image_url,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)
    return user


async def _issue_tokens(db: AsyncSession, user: User, device_info: str | None = None) -> TokenResponse:
    raw_refresh, token_hash, expires_at = generate_refresh_token()
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=expires_at,
            device_info=device_info,
        )
    )
    await db.commit()
    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=raw_refresh,
        user=UserOut.model_validate(user),
    )


# ── 엔드포인트 ───────────────────────────────────────────────────
@router.post("/google", response_model=TokenResponse)
async def login_google(body: GoogleLoginRequest, db: AsyncSession = Depends(get_db)):
    if not GOOGLE_CLIENT_ID:
        raise HTTPException(status_code=500, detail="GOOGLE_CLIENT_ID가 서버에 설정되지 않았습니다.")

    try:
        # google-auth는 동기 라이브러리라 스레드로 돌린다 (Gemini 호출과 동일 패턴).
        idinfo = await asyncio.to_thread(
            google_id_token.verify_oauth2_token,
            body.id_token,
            google_requests.Request(),
            GOOGLE_CLIENT_ID,
        )
    except ValueError as e:
        raise HTTPException(status_code=401, detail=f"구글 토큰 검증 실패: {e}")

    user = await _find_or_create_user(
        db,
        provider="google",
        provider_user_id=idinfo["sub"],
        email=idinfo.get("email"),
        nickname=idinfo.get("name") or "구글사용자",
        profile_image_url=idinfo.get("picture"),
    )
    return await _issue_tokens(db, user)


@router.post("/kakao", response_model=TokenResponse)
async def login_kakao(body: KakaoLoginRequest, db: AsyncSession = Depends(get_db)):
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(
            "https://kapi.kakao.com/v2/user/me",
            headers={"Authorization": f"Bearer {body.access_token}"},
        )

    if resp.status_code != 200:
        raise HTTPException(status_code=401, detail=f"카카오 토큰 검증 실패: {resp.text}")

    data = resp.json()
    account = data.get("kakao_account") or {}
    profile = account.get("profile") or {}

    user = await _find_or_create_user(
        db,
        provider="kakao",
        provider_user_id=str(data["id"]),
        email=account.get("email"),
        nickname=profile.get("nickname") or "카카오사용자",
        profile_image_url=profile.get("profile_image_url"),
    )
    return await _issue_tokens(db, user)


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    token_hash = hash_token(body.refresh_token)
    result = await db.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
    rt = result.scalar_one_or_none()

    if rt is None or rt.revoked_at is not None or rt.expires_at < datetime.now(timezone.utc):
        raise HTTPException(status_code=401, detail="refresh token이 유효하지 않습니다. 다시 로그인해주세요.")

    user = await db.get(User, rt.user_id)
    if user is None:
        raise HTTPException(status_code=401, detail="사용자를 찾을 수 없습니다.")

    # 토큰 회전(rotation): 기존 refresh token은 즉시 무효화하고 새로 발급.
    # 탈취된 토큰이 재사용되는 걸 막기 위한 표준적인 방식.
    rt.revoked_at = datetime.now(timezone.utc)
    tokens = await _issue_tokens(db, user, device_info=rt.device_info)
    await db.commit()
    return tokens


@router.post("/logout")
async def logout(body: LogoutRequest, db: AsyncSession = Depends(get_db)):
    token_hash = hash_token(body.refresh_token)
    result = await db.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
    rt = result.scalar_one_or_none()
    if rt is not None and rt.revoked_at is None:
        rt.revoked_at = datetime.now(timezone.utc)
        await db.commit()
    return {"status": "logged_out"}
