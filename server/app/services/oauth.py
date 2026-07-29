from dataclasses import dataclass
from typing import Protocol

import httpx
from google.auth.transport import requests as google_auth_requests
from google.oauth2 import id_token as google_id_token
from starlette.concurrency import run_in_threadpool

from app.core.config import get_settings


@dataclass(frozen=True)
class OAuthUserInfo:
    """provider별 검증 결과를 담는 공통 형태."""

    provider_user_id: str
    nickname: str
    email: str | None = None
    profile_image_url: str | None = None


class OAuthVerificationError(Exception):
    """oauth_token 검증 실패 (서명/만료/aud 불일치, provider API 오류 등)."""


class UnsupportedProviderError(Exception):
    pass


class OAuthVerifier(Protocol):
    async def verify(self, oauth_token: str) -> OAuthUserInfo: ...


class GoogleOAuthVerifier:
    """oauth_token = Google id_token. 서명 + aud(클라이언트 ID)를 검증한다."""

    def __init__(self, client_id: str) -> None:
        self._client_id = client_id

    async def verify(self, oauth_token: str) -> OAuthUserInfo:
        try:
            # google-auth의 verify_oauth2_token은 동기 함수(공개키 fetch 포함)라
            # 이벤트 루프를 막지 않도록 스레드풀에서 실행한다.
            payload = await run_in_threadpool(
                google_id_token.verify_oauth2_token,
                oauth_token,
                google_auth_requests.Request(),
                self._client_id,
            )
        except ValueError as exc:
            raise OAuthVerificationError(str(exc)) from exc

        email = payload.get("email")
        nickname = payload.get("name") or (email.split("@")[0] if email else None) or "사용자"

        return OAuthUserInfo(
            provider_user_id=str(payload["sub"]),
            nickname=nickname,
            email=email,
            profile_image_url=payload.get("picture"),
        )


class KakaoOAuthVerifier:
    """oauth_token = Kakao access_token. /v2/user/me 호출로 신원을 확인한다."""

    _USER_ME_URL = "https://kapi.kakao.com/v2/user/me"

    async def verify(self, oauth_token: str) -> OAuthUserInfo:
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(
                    self._USER_ME_URL,
                    headers={"Authorization": f"Bearer {oauth_token}"},
                )
        except httpx.HTTPError as exc:
            raise OAuthVerificationError(str(exc)) from exc

        if response.status_code != 200:
            raise OAuthVerificationError(
                f"kakao /v2/user/me returned {response.status_code}: {response.text}"
            )

        data = response.json()
        kakao_account = data.get("kakao_account") or {}
        profile = kakao_account.get("profile") or {}

        return OAuthUserInfo(
            provider_user_id=str(data["id"]),
            nickname=profile.get("nickname") or "사용자",
            email=kakao_account.get("email"),
            profile_image_url=profile.get("profile_image_url"),
        )


def get_oauth_verifier(provider: str) -> OAuthVerifier:
    """provider(이미 검증된 값)에 대응하는 verifier를 반환한다.

    UNSUPPORTED_PROVIDER 여부는 호출부(app/api/auth.py)에서
    body.provider를 먼저 걸러내므로 여기서는 두 값만 다룬다.
    """
    if provider == "google":
        return GoogleOAuthVerifier(client_id=get_settings().google_oauth_client_id)
    if provider == "kakao":
        return KakaoOAuthVerifier()
    raise UnsupportedProviderError(provider)
