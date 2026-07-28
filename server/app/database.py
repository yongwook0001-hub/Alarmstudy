# server/app/database.py
#
# 비동기 SQLAlchemy 연결/세션 설정.
# 팀원의 docker-compose.yml이 이미 postgresql+asyncpg:// 형식의 DATABASE_URL을
# api 컨테이너에 주입하도록 되어 있어서(POSTGRES_USER/PASSWORD/DB 조합), 그 값을 그대로 사용한다.
# 로컬에서 docker 없이 uvicorn만 직접 띄울 땐 DATABASE_URL을 .env에 직접 넣으면 된다.
import os

from dotenv import load_dotenv
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

load_dotenv()

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://alarmstudy:alarmstudy_pw@localhost:5432/alarmstudy_db",
)

engine = create_async_engine(DATABASE_URL, future=True)
AsyncSessionLocal = async_sessionmaker(bind=engine, expire_on_commit=False)


class Base(DeclarativeBase):
    """다른 테이블(material_sets, alarms, questions 등)도 이 Base를 공유해서
    같은 메타데이터/마이그레이션 체계 안에 들어오면 된다."""
    pass


async def get_db():
    """FastAPI Depends용 비동기 세션 제공자."""
    async with AsyncSessionLocal() as session:
        yield session
