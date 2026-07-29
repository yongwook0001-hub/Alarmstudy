import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.db.session import engine
from app.main import app


@pytest_asyncio.fixture(autouse=True)
async def _clean_auth_tables():
    """각 테스트를 users/refresh_tokens가 비어있는 상태에서 시작한다."""
    async with engine.begin() as conn:
        await conn.execute(text("TRUNCATE TABLE refresh_tokens, users RESTART IDENTITY CASCADE"))
    yield


@pytest_asyncio.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
