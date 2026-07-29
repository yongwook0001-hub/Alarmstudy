from datetime import datetime, timedelta, timezone

import jwt
from sqlalchemy import select

from app.core.config import get_settings
from app.core.security import JWT_ALGORITHM, hash_refresh_token
from app.db.session import AsyncSessionLocal
from app.models import RefreshToken
from app.services.oauth import OAuthUserInfo, OAuthVerificationError


class _FakeVerifier:
    def __init__(self, info: OAuthUserInfo | None = None, error: Exception | None = None) -> None:
        self._info = info
        self._error = error

    async def verify(self, oauth_token: str) -> OAuthUserInfo:
        if self._error is not None:
            raise self._error
        assert self._info is not None
        return self._info


GOOGLE_USER_A = OAuthUserInfo(
    provider_user_id="google-uid-1",
    nickname="철수",
    email="chulsoo@example.com",
    profile_image_url="https://example.com/a.png",
)


def _patch_verifier(monkeypatch, verifier: _FakeVerifier) -> None:
    monkeypatch.setattr("app.api.auth.get_oauth_verifier", lambda provider: verifier)


async def _login(
    client,
    monkeypatch,
    info: OAuthUserInfo | None = None,
    error: Exception | None = None,
    device_info: str | None = None,
    provider: str = "google",
):
    _patch_verifier(monkeypatch, _FakeVerifier(info=info, error=error))
    return await client.post(
        "/api/auth/login",
        json={"provider": provider, "oauth_token": "irrelevant", "device_info": device_info},
    )


# ---- login ------------------------------------------------------------


async def test_login_creates_new_user(client, monkeypatch):
    resp = await _login(client, monkeypatch, info=GOOGLE_USER_A)

    assert resp.status_code == 200
    body = resp.json()
    assert body["is_new_user"] is True
    assert body["user"]["nickname"] == "철수"
    assert body["user"]["email"] == "chulsoo@example.com"
    assert body["access_token"]
    assert body["refresh_token"]


async def test_login_existing_user_reuses_row(client, monkeypatch):
    first = await _login(client, monkeypatch, info=GOOGLE_USER_A)
    second = await _login(client, monkeypatch, info=GOOGLE_USER_A)

    assert first.json()["is_new_user"] is True
    assert second.json()["is_new_user"] is False
    assert first.json()["user"]["id"] == second.json()["user"]["id"]


async def test_login_same_device_revokes_previous_token(client, monkeypatch):
    first = await _login(client, monkeypatch, info=GOOGLE_USER_A, device_info="phone-1")
    await _login(client, monkeypatch, info=GOOGLE_USER_A, device_info="phone-1")

    old_refresh_token = first.json()["refresh_token"]

    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(old_refresh_token))
        )
        row = result.scalar_one()
        assert row.revoked_at is not None


async def test_login_unsupported_provider(client, monkeypatch):
    resp = await _login(client, monkeypatch, info=GOOGLE_USER_A, provider="naver")

    assert resp.status_code == 400
    assert resp.json()["error_code"] == "UNSUPPORTED_PROVIDER"


async def test_login_invalid_oauth_token(client, monkeypatch):
    resp = await _login(client, monkeypatch, error=OAuthVerificationError("bad signature"))

    assert resp.status_code == 401
    assert resp.json()["error_code"] == "INVALID_OAUTH_TOKEN"


# ---- refresh ------------------------------------------------------------


async def test_refresh_success(client, monkeypatch):
    login_resp = await _login(client, monkeypatch, info=GOOGLE_USER_A)
    refresh_token = login_resp.json()["refresh_token"]

    resp = await client.post("/api/auth/refresh", json={"refresh_token": refresh_token})

    assert resp.status_code == 200
    settings = get_settings()
    payload = jwt.decode(resp.json()["access_token"], settings.jwt_secret_key, algorithms=[JWT_ALGORITHM])
    assert payload["sub"] == str(login_resp.json()["user"]["id"])


async def test_refresh_invalid_token(client):
    resp = await client.post("/api/auth/refresh", json={"refresh_token": "no-such-token"})

    assert resp.status_code == 401
    assert resp.json()["error_code"] == "REFRESH_TOKEN_INVALID"


async def test_refresh_revoked_token_is_invalid_not_expired(client, monkeypatch):
    first = await _login(client, monkeypatch, info=GOOGLE_USER_A, device_info="phone-1")
    await _login(client, monkeypatch, info=GOOGLE_USER_A, device_info="phone-1")

    resp = await client.post("/api/auth/refresh", json={"refresh_token": first.json()["refresh_token"]})

    assert resp.status_code == 401
    assert resp.json()["error_code"] == "REFRESH_TOKEN_INVALID"


async def test_refresh_expired_token(client, monkeypatch):
    login_resp = await _login(client, monkeypatch, info=GOOGLE_USER_A)
    user_id = login_resp.json()["user"]["id"]

    expired_raw = "expired-raw-token-for-test"
    async with AsyncSessionLocal() as db:
        db.add(
            RefreshToken(
                user_id=user_id,
                token_hash=hash_refresh_token(expired_raw),
                expires_at=datetime.now(timezone.utc) - timedelta(days=1),
            )
        )
        await db.commit()

    resp = await client.post("/api/auth/refresh", json={"refresh_token": expired_raw})

    assert resp.status_code == 401
    assert resp.json()["error_code"] == "REFRESH_TOKEN_EXPIRED"


# ---- logout ------------------------------------------------------------


async def test_logout_is_idempotent_and_revokes(client, monkeypatch):
    login_resp = await _login(client, monkeypatch, info=GOOGLE_USER_A)
    headers = {"Authorization": f"Bearer {login_resp.json()['access_token']}"}
    refresh_token = login_resp.json()["refresh_token"]

    first = await client.post("/api/auth/logout", json={"refresh_token": refresh_token}, headers=headers)
    second = await client.post("/api/auth/logout", json={"refresh_token": refresh_token}, headers=headers)

    assert first.status_code == 200
    assert second.status_code == 200

    refresh_resp = await client.post("/api/auth/refresh", json={"refresh_token": refresh_token})
    assert refresh_resp.status_code == 401
    assert refresh_resp.json()["error_code"] == "REFRESH_TOKEN_INVALID"


async def test_logout_requires_bearer(client):
    resp = await client.post("/api/auth/logout", json={"refresh_token": "whatever"})

    assert resp.status_code == 401
    assert resp.json()["error_code"] == "ACCESS_TOKEN_INVALID"


# ---- users/me GET ------------------------------------------------------------


async def test_me_returns_profile(client, monkeypatch):
    login_resp = await _login(client, monkeypatch, info=GOOGLE_USER_A)
    headers = {"Authorization": f"Bearer {login_resp.json()['access_token']}"}

    resp = await client.get("/api/users/me", headers=headers)

    assert resp.status_code == 200
    body = resp.json()
    assert body["nickname"] == "철수"
    assert body["provider"] == "google"
    assert "created_at" in body


async def test_me_without_token(client):
    resp = await client.get("/api/users/me")

    assert resp.status_code == 401
    assert resp.json()["error_code"] == "ACCESS_TOKEN_INVALID"


async def test_me_with_malformed_token(client):
    resp = await client.get("/api/users/me", headers={"Authorization": "Bearer garbage"})

    assert resp.status_code == 401
    assert resp.json()["error_code"] == "ACCESS_TOKEN_INVALID"


async def test_me_with_expired_token_is_distinguished_from_invalid(client, monkeypatch):
    login_resp = await _login(client, monkeypatch, info=GOOGLE_USER_A)
    user_id = login_resp.json()["user"]["id"]

    settings = get_settings()
    expired_token = jwt.encode(
        {
            "sub": str(user_id),
            "iat": datetime.now(timezone.utc) - timedelta(minutes=60),
            "exp": datetime.now(timezone.utc) - timedelta(minutes=1),
        },
        settings.jwt_secret_key,
        algorithm=JWT_ALGORITHM,
    )

    resp = await client.get("/api/users/me", headers={"Authorization": f"Bearer {expired_token}"})

    assert resp.status_code == 401
    assert resp.json()["error_code"] == "ACCESS_TOKEN_EXPIRED"


# ---- users/me DELETE ------------------------------------------------------------


async def test_delete_me_hard_deletes(client, monkeypatch):
    login_resp = await _login(client, monkeypatch, info=GOOGLE_USER_A)
    headers = {"Authorization": f"Bearer {login_resp.json()['access_token']}"}

    resp = await client.delete("/api/users/me", headers=headers)
    assert resp.status_code == 200

    me_resp = await client.get("/api/users/me", headers=headers)
    assert me_resp.status_code == 401
    assert me_resp.json()["error_code"] == "ACCESS_TOKEN_INVALID"
