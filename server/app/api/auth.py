import logging
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user_id
from app.core.constants import REFRESH_TOKEN_EXPIRE_DAYS
from app.core.errors import AppError
from app.core.security import create_access_token, generate_refresh_token, hash_refresh_token
from app.db.session import get_db
from app.models import MaterialSet, RefreshToken, StudyMaterial, User
from app.services.oauth import OAuthVerificationError, get_oauth_verifier
from app.services.user import delete_user_s3_objects

logger = logging.getLogger(__name__)

router = APIRouter()

_SUPPORTED_PROVIDERS = ("google", "kakao")


# ---- schemas ---------------------------------------------------------------


class LoginRequest(BaseModel):
    provider: str
    oauth_token: str
    device_info: str | None = None


class UserOut(BaseModel):
    id: int
    nickname: str
    email: str | None
    profile_image_url: str | None


class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    user: UserOut
    is_new_user: bool


class RefreshRequest(BaseModel):
    refresh_token: str


class RefreshResponse(BaseModel):
    access_token: str


class LogoutRequest(BaseModel):
    refresh_token: str


class UserMeResponse(BaseModel):
    id: int
    provider: str
    nickname: str
    email: str | None
    profile_image_url: str | None
    created_at: datetime


# ---- routes ------------------------------------------------------------


@router.post("/auth/login", response_model=LoginResponse)
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db)) -> LoginResponse:
    if body.provider not in _SUPPORTED_PROVIDERS:
        raise AppError(400, "UNSUPPORTED_PROVIDER", f"지원하지 않는 provider입니다: {body.provider}")

    verifier = get_oauth_verifier(body.provider)
    try:
        oauth_info = await verifier.verify(body.oauth_token)
    except OAuthVerificationError as exc:
        raise AppError(401, "INVALID_OAUTH_TOKEN", "OAuth 토큰 검증에 실패했습니다.") from exc

    result = await db.execute(
        select(User).where(
            User.provider == body.provider,
            User.provider_user_id == oauth_info.provider_user_id,
        )
    )
    user = result.scalar_one_or_none()
    is_new_user = user is None
    nickname = oauth_info.nickname[:50]

    if user is None:
        user = User(
            provider=body.provider,
            provider_user_id=oauth_info.provider_user_id,
            email=oauth_info.email,
            nickname=nickname,
            profile_image_url=oauth_info.profile_image_url,
        )
        db.add(user)
        await db.flush()  # user.id 확보
    else:
        # 매 로그인마다 최신 OAuth 프로필로 갱신 (닉네임/이메일/사진 변경 반영)
        user.nickname = nickname
        user.email = oauth_info.email
        user.profile_image_url = oauth_info.profile_image_url

    # 같은 device_info의 기존 토큰 revoke 후 신규 발급 (기기당 1개).
    # device_info가 없으면 어떤 기기인지 식별할 수 없으므로 스킵한다.
    if body.device_info:
        await db.execute(
            update(RefreshToken)
            .where(
                RefreshToken.user_id == user.id,
                RefreshToken.device_info == body.device_info,
                RefreshToken.revoked_at.is_(None),
            )
            .values(revoked_at=datetime.now(timezone.utc))
        )

    raw_refresh_token = generate_refresh_token()
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_refresh_token(raw_refresh_token),
            expires_at=datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS),
            device_info=body.device_info,
        )
    )
    await db.commit()

    return LoginResponse(
        access_token=create_access_token(user.id),
        refresh_token=raw_refresh_token,
        user=UserOut(
            id=user.id,
            nickname=user.nickname,
            email=user.email,
            profile_image_url=user.profile_image_url,
        ),
        is_new_user=is_new_user,
    )


@router.post("/auth/refresh", response_model=RefreshResponse)
async def refresh(body: RefreshRequest, db: AsyncSession = Depends(get_db)) -> RefreshResponse:
    token_hash = hash_refresh_token(body.refresh_token)
    result = await db.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
    token_row = result.scalar_one_or_none()

    if token_row is None or token_row.revoked_at is not None:
        raise AppError(401, "REFRESH_TOKEN_INVALID", "유효하지 않은 refresh token입니다.")

    if token_row.expires_at < datetime.now(timezone.utc):
        raise AppError(401, "REFRESH_TOKEN_EXPIRED", "refresh token이 만료되었습니다.")

    # 회전 없음 — Access만 재발급, refresh_tokens row는 그대로 둔다.
    return RefreshResponse(access_token=create_access_token(token_row.user_id))


@router.post("/auth/logout")
async def logout(
    body: LogoutRequest,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    token_hash = hash_refresh_token(body.refresh_token)
    # 이미 revoke된 토큰/존재하지 않는 토큰/타인의 토큰이어도 0 row 매치로 조용히 넘어간다 (멱등).
    await db.execute(
        update(RefreshToken)
        .where(
            RefreshToken.token_hash == token_hash,
            RefreshToken.user_id == user_id,
            RefreshToken.revoked_at.is_(None),
        )
        .values(revoked_at=datetime.now(timezone.utc))
    )
    await db.commit()
    return {}


@router.get("/users/me", response_model=UserMeResponse)
async def get_me(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> UserMeResponse:
    user = await db.get(User, user_id)
    if user is None:
        # 서명은 유효하나 대상 유저가 이미 없는 경우 (탈퇴 후 재사용된 access token 등)
        raise AppError(401, "ACCESS_TOKEN_INVALID", "유효하지 않은 사용자입니다.")

    return UserMeResponse(
        id=user.id,
        provider=user.provider,
        nickname=user.nickname,
        email=user.email,
        profile_image_url=user.profile_image_url,
        created_at=user.created_at,
    )


@router.delete("/users/me")
async def delete_me(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    user = await db.get(User, user_id)
    if user is None:
        return {}

    s3_key_result = await db.execute(
        select(StudyMaterial.s3_key)
        .join(MaterialSet, StudyMaterial.set_id == MaterialSet.id)
        .where(MaterialSet.user_id == user_id)
    )
    s3_keys = list(s3_key_result.scalars().all())

    try:
        await delete_user_s3_objects(s3_keys)
    except Exception:
        # 설계: S3 삭제가 실패해도 DB 삭제는 진행한다. 로그만 남긴다.
        logger.exception("S3 객체 삭제 실패 (user_id=%s) — DB 삭제는 계속 진행", user_id)

    await db.delete(user)  # ON DELETE CASCADE로 연쇄삭제
    await db.commit()
    return {}
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user_id
from app.core.constants import REFRESH_TOKEN_EXPIRE_DAYS
from app.core.errors import AppError
from app.core.security import create_access_token, generate_refresh_token, hash_refresh_token
from app.db.session import get_db
from app.models import MaterialSet, RefreshToken, StudyMaterial, User
from app.services.oauth import OAuthVerificationError, get_oauth_verifier
from app.services.user import delete_user_s3_objects

router = APIRouter()

_SUPPORTED_PROVIDERS = ("google", "kakao")


# ---- schemas ---------------------------------------------------------------


class LoginRequest(BaseModel):
    provider: str
    oauth_token: str
    device_info: str | None = None


class UserOut(BaseModel):
    id: int
    nickname: str
    email: str | None
    profile_image_url: str | None


class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    user: UserOut
    is_new_user: bool


class RefreshRequest(BaseModel):
    refresh_token: str


class RefreshResponse(BaseModel):
    access_token: str


class LogoutRequest(BaseModel):
    refresh_token: str


class UserMeResponse(BaseModel):
    id: int
    provider: str
    nickname: str
    email: str | None
    profile_image_url: str | None
    created_at: datetime


# ---- routes ------------------------------------------------------------


@router.post("/auth/login", response_model=LoginResponse)
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db)) -> LoginResponse:
    if body.provider not in _SUPPORTED_PROVIDERS:
        raise AppError(400, "UNSUPPORTED_PROVIDER", f"지원하지 않는 provider입니다: {body.provider}")

    verifier = get_oauth_verifier(body.provider)
    try:
        oauth_info = await verifier.verify(body.oauth_token)
    except OAuthVerificationError as exc:
        raise AppError(401, "INVALID_OAUTH_TOKEN", "OAuth 토큰 검증에 실패했습니다.") from exc

    result = await db.execute(
        select(User).where(
            User.provider == body.provider,
            User.provider_user_id == oauth_info.provider_user_id,
        )
    )
    user = result.scalar_one_or_none()
    is_new_user = user is None
    nickname = oauth_info.nickname[:50]

    if user is None:
        user = User(
            provider=body.provider,
            provider_user_id=oauth_info.provider_user_id,
            email=oauth_info.email,
            nickname=nickname,
            profile_image_url=oauth_info.profile_image_url,
        )
        db.add(user)
        await db.flush()  # user.id 확보
    else:
        # 매 로그인마다 최신 OAuth 프로필로 갱신 (닉네임/이메일/사진 변경 반영)
        user.nickname = nickname
        user.email = oauth_info.email
        user.profile_image_url = oauth_info.profile_image_url

    # 같은 device_info의 기존 토큰 revoke 후 신규 발급 (기기당 1개).
    # device_info가 없으면 어떤 기기인지 식별할 수 없으므로 스킵한다.
    if body.device_info:
        await db.execute(
            update(RefreshToken)
            .where(
                RefreshToken.user_id == user.id,
                RefreshToken.device_info == body.device_info,
                RefreshToken.revoked_at.is_(None),
            )
            .values(revoked_at=datetime.now(timezone.utc))
        )

    raw_refresh_token = generate_refresh_token()
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_refresh_token(raw_refresh_token),
            expires_at=datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS),
            device_info=body.device_info,
        )
    )
    await db.commit()

    return LoginResponse(
        access_token=create_access_token(user.id),
        refresh_token=raw_refresh_token,
        user=UserOut(
            id=user.id,
            nickname=user.nickname,
            email=user.email,
            profile_image_url=user.profile_image_url,
        ),
        is_new_user=is_new_user,
    )


@router.post("/auth/refresh", response_model=RefreshResponse)
async def refresh(body: RefreshRequest, db: AsyncSession = Depends(get_db)) -> RefreshResponse:
    token_hash = hash_refresh_token(body.refresh_token)
    result = await db.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
    token_row = result.scalar_one_or_none()

    if token_row is None or token_row.revoked_at is not None:
        raise AppError(401, "REFRESH_TOKEN_INVALID", "유효하지 않은 refresh token입니다.")

    if token_row.expires_at < datetime.now(timezone.utc):
        raise AppError(401, "REFRESH_TOKEN_EXPIRED", "refresh token이 만료되었습니다.")

    # 회전 없음 — Access만 재발급, refresh_tokens row는 그대로 둔다.
    return RefreshResponse(access_token=create_access_token(token_row.user_id))


@router.post("/auth/logout")
async def logout(
    body: LogoutRequest,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    token_hash = hash_refresh_token(body.refresh_token)
    # 이미 revoke된 토큰/존재하지 않는 토큰/타인의 토큰이어도 0 row 매치로 조용히 넘어간다 (멱등).
    await db.execute(
        update(RefreshToken)
        .where(
            RefreshToken.token_hash == token_hash,
            RefreshToken.user_id == user_id,
            RefreshToken.revoked_at.is_(None),
        )
        .values(revoked_at=datetime.now(timezone.utc))
    )
    await db.commit()
    return {}


@router.get("/users/me", response_model=UserMeResponse)
async def get_me(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> UserMeResponse:
    user = await db.get(User, user_id)
    if user is None:
        # 서명은 유효하나 대상 유저가 이미 없는 경우 (탈퇴 후 재사용된 access token 등)
        raise AppError(401, "ACCESS_TOKEN_INVALID", "유효하지 않은 사용자입니다.")

    return UserMeResponse(
        id=user.id,
        provider=user.provider,
        nickname=user.nickname,
        email=user.email,
        profile_image_url=user.profile_image_url,
        created_at=user.created_at,
    )


@router.delete("/users/me")
async def delete_me(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    user = await db.get(User, user_id)
    if user is None:
        return {}

    s3_key_result = await db.execute(
        select(StudyMaterial.s3_key)
        .join(MaterialSet, StudyMaterial.set_id == MaterialSet.id)
        .where(MaterialSet.user_id == user_id)
    )
    s3_keys = list(s3_key_result.scalars().all())

    # delete_user_s3_objects 내부에서 실패를 삼키므로(설계: S3 실패해도 DB 삭제 진행)
    # 별도 예외처리 없이 그대로 호출한다.
    await delete_user_s3_objects(s3_keys)

    await db.delete(user)  # ON DELETE CASCADE로 연쇄삭제
    await db.commit()
    return {}
