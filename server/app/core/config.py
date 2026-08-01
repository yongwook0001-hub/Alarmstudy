from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv
from pydantic_settings import BaseSettings, SettingsConfigDict

_ENV_FILE = Path(__file__).resolve().parents[2] / ".env"

# boto3는 pydantic-settings가 아니라 os.environ의 AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY를
# 기본 자격증명 체인으로 직접 읽으므로, 여기서 명시적으로 .env를 프로세스 환경에 로드해둔다.
load_dotenv(_ENV_FILE)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=_ENV_FILE, extra="ignore")

    postgres_db: str
    postgres_user: str
    postgres_password: str
    postgres_host: str = "localhost"
    postgres_port: int = 5432

    # docker-compose는 이 값을 직접 조립해 컨테이너 환경변수로 주입한다.
    # 로컬(호스트)에서 alembic 등을 돌릴 때는 미설정 상태로 두고 아래 프로퍼티가 조립한다.
    database_url: str | None = None

    jwt_secret_key: str
    google_oauth_client_id: str

    aws_region: str
    s3_bucket_name: str
    # AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY는 여기 필드로 두지 않는다 — boto3 기본
    # 자격증명 체인(환경변수)이 직접 읽도록 둔다 (위 load_dotenv로 os.environ에 이미 있음).

    gemini_api_key: str

    @property
    def sqlalchemy_database_url(self) -> str:
        if self.database_url:
            return self.database_url
        return (
            f"postgresql+asyncpg://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_ENV_FILE = Path(__file__).resolve().parents[2] / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=_ENV_FILE, extra="ignore")

    postgres_db: str
    postgres_user: str
    postgres_password: str
    postgres_host: str = "localhost"
    postgres_port: int = 5432

    # docker-compose는 이 값을 직접 조립해 컨테이너 환경변수로 주입한다.
    # 로컬(호스트)에서 alembic 등을 돌릴 때는 미설정 상태로 두고 아래 프로퍼티가 조립한다.
    database_url: str | None = None

    jwt_secret_key: str
    google_oauth_client_id: str

    @property
    def sqlalchemy_database_url(self) -> str:
        if self.database_url:
            return self.database_url
        return (
            f"postgresql+asyncpg://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
