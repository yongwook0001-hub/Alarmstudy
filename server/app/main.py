# server/app/main.py
#
# FastAPI 앱 진입점. 라우터 조립과 lifespan(워커 기동)만 담당한다.
#
# 인증(구글/카카오 로그인 + JWT)은 팀원이 만든 app/api/auth.py 라우터를 그대로 사용.
# users/refresh_tokens 포함 전체 DB 스키마(alarms, material_sets, questions 등)는
# 팀원이 app/models/, app/db/, alembic/로 이미 구성해뒀다.
import asyncio
import contextlib
from collections.abc import AsyncIterator

from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.api.alarms import router as alarms_router

# .env 파일에서 환경 변수(API 키) 로드
# 주의: 아래 app.api.song import가 이 줄보다 먼저 실행되면 song.py의
# `GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")`(모듈 로드 시점에 딱 한 번 평가됨)가
# .env 로드 전이라 항상 빈 값이 됨 — 그래서 load_dotenv()를 import들보다 위로 옮김.
load_dotenv()

from app.api.auth import router as auth_router
from app.api.materials import router as materials_router
from app.api.sessions import router as sessions_router
from app.api.sets import router as sets_router
from app.api.song import router as song_router
from app.api.stats import router as stats_router
from app.core.errors import AppError
from app.db.session import AsyncSessionLocal
from app.workers import generation_worker


@contextlib.asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    async with AsyncSessionLocal() as db:
        await generation_worker.recover_stale_processing_jobs(db)
        await db.commit()

    worker_task = asyncio.create_task(generation_worker.run_poll_loop())
    try:
        yield
    finally:
        # 진행 중이던 job은 processing에 남을 수 있다 — 다음 기동 시 위 복구 로직이 되돌린다.
        worker_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await worker_task


app = FastAPI(title="AlarmStudy AI Server", lifespan=lifespan)


@app.exception_handler(AppError)
async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content={"error_code": exc.error_code, "message": exc.message})


app.include_router(auth_router, prefix="/api")
app.include_router(sets_router, prefix="/api")
app.include_router(materials_router, prefix="/api")
app.include_router(alarms_router, prefix="/api")
app.include_router(sessions_router, prefix="/api")
app.include_router(stats_router, prefix="/api")
app.include_router(song_router, prefix="/api")


@app.get("/")
def read_root():
    return {"status": "AlarmStudy AI Server is running"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
