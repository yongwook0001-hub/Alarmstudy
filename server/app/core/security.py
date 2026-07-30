import hashlib
import secrets
from datetime import datetime, timedelta, timezone

import jwt

from app.core.config import get_settings
from app.core.constants import ACCESS_TOKEN_EXPIRE_MINUTES

JWT_ALGORITHM = "HS256"


class TokenExpiredError(Exception):
    pass


class TokenInvalidError(Exception):
    pass


def create_access_token(user_id: int) -> str:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "iat": now,
        "exp": now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> int:
    """Access 토큰을 로컬 서명검증만으로 디코드한다 (DB조회·외부호출 없음 — 설계 확정).

    Returns:
        토큰에 담긴 user_id.

    Raises:
        TokenExpiredError: 서명은 유효하나 만료된 경우.
        TokenInvalidError: 서명이 무효하거나 형식이 잘못된 경우.
    """
    settings = get_settings()
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError as exc:
        raise TokenExpiredError from exc
    except jwt.InvalidTokenError as exc:
        raise TokenInvalidError from exc

    try:
        return int(payload["sub"])
    except (KeyError, TypeError, ValueError) as exc:
        raise TokenInvalidError from exc


def generate_refresh_token() -> str:
    """Refresh token은 JWT가 아니라 불투명(opaque) 랜덤 문자열이다.

    refresh_tokens 테이블 자체가 user_id/expires_at/revoked_at을 들고 있어
    (token_hash로 조회하는) DB 조회가 검증의 본체이므로, JWT로 인코딩해도
    얻는 정보가 없다. 원문은 응답으로만 내려주고 DB에는 해시만 저장한다.
    """
    return secrets.token_urlsafe(48)


def hash_refresh_token(token: str) -> str:
    """SHA-256 해시(hex, 64자) — refresh_tokens.token_hash CHAR(64)에 맞춘다."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()
