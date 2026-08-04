from datetime import date, datetime, timedelta
from typing import Literal

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import Date, cast, func, select
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user_id, get_owned_material_set
from app.core.errors import AppError
from app.db.session import get_db
from app.models import Alarm, AlarmSession, MaterialSet, QuestionAttempt, StudyMaterial, WeakAreaAnalysis, WrongAnswer

router = APIRouter()


# ---- schemas ---------------------------------------------------------------


class WrongAnswerOut(BaseModel):
    id: int
    material_id: int
    content: str
    choices: list[str]
    correct_answer: int
    explanation: str | None
    topic: str
    wrong_count: int
    last_wrong_at: datetime


class WrongAnswerListResponse(BaseModel):
    items: list[WrongAnswerOut]
    total: int
    page: int
    size: int


class AnalysisResponse(BaseModel):
    set_id: int
    weak_topics: list[dict] | None
    comment: str | None
    analyzed_at: datetime | None
    total_attempts: int
    correct_count: int
    overall_accuracy: float


class StatsSummaryResponse(BaseModel):
    current_streak: int
    total_study_days: int
    total_attempts: int
    correct_rate: float
    total_sets: int
    active_alarms: int


# ---- helpers ------------------------------------------------------------


def _compute_streak(dismissed_dates: set[date], today: date) -> int:
    """dismissed 세션이 있었던 날짜 집합에서 연속일을 센다.

    가장 최근 기록일이 오늘도 어제도 아니면(즉, 어제까지도 이어지지 않았으면) 이미
    끊긴 것이므로 0. 그렇지 않으면 그 최근일부터 하루씩 거슬러 올라가며 센다.
    """
    if not dismissed_dates:
        return 0

    latest = max(dismissed_dates)
    if latest != today and latest != today - timedelta(days=1):
        return 0

    streak = 1
    current = latest
    while (current - timedelta(days=1)) in dismissed_dates:
        streak += 1
        current -= timedelta(days=1)
    return streak


# ---- routes ------------------------------------------------------------


@router.get("/wrong-answers", response_model=WrongAnswerListResponse)
async def list_wrong_answers(
    set_id: int | None = Query(None),
    topic: str | None = Query(None),
    sort: Literal["recent", "most_wrong"] = Query("recent"),
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1),
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> WrongAnswerListResponse:
    filters = [WrongAnswer.user_id == user_id]
    if set_id is not None:
        filters.append(WrongAnswer.material_id.in_(select(StudyMaterial.id).where(StudyMaterial.set_id == set_id)))
    if topic is not None:
        filters.append(WrongAnswer.topic == topic)

    total = await db.scalar(select(func.count(WrongAnswer.id)).where(*filters))

    order_by = WrongAnswer.last_wrong_at.desc() if sort == "recent" else WrongAnswer.wrong_count.desc()
    result = await db.execute(
        select(WrongAnswer).where(*filters).order_by(order_by).offset((page - 1) * size).limit(size)
    )
    items = list(result.scalars().all())

    return WrongAnswerListResponse(
        items=[
            WrongAnswerOut(
                id=w.id,
                material_id=w.material_id,
                content=w.content,
                choices=w.choices,
                correct_answer=w.correct_answer,
                explanation=w.explanation,
                topic=w.topic,
                wrong_count=w.wrong_count,
                last_wrong_at=w.last_wrong_at,
            )
            for w in items
        ],
        total=total or 0,
        page=page,
        size=size,
    )


@router.get("/sets/{set_id}/analysis", response_model=AnalysisResponse)
async def get_set_analysis(
    material_set: MaterialSet = Depends(get_owned_material_set),
    db: AsyncSession = Depends(get_db),
) -> AnalysisResponse:
    # 세트 단위 정답률은 집계 테이블 없이 매 요청 실시간 계산 — attempts가 material_id로만
    # 세트에 연결되므로 study_materials를 거쳐 조인해야 한다.
    total_attempts, correct_count = (
        await db.execute(
            select(
                func.count(QuestionAttempt.id),
                func.count(QuestionAttempt.id).filter(QuestionAttempt.is_correct.is_(True)),
            )
            .join(StudyMaterial, QuestionAttempt.material_id == StudyMaterial.id)
            .where(StudyMaterial.set_id == material_set.id)
        )
    ).one()
    total_attempts = total_attempts or 0
    correct_count = correct_count or 0
    overall_accuracy = round(100 * correct_count / total_attempts, 1) if total_attempts else 0.0

    analysis = await db.scalar(select(WeakAreaAnalysis).where(WeakAreaAnalysis.set_id == material_set.id))
    if analysis is None:
        # 분석(weak_topics/comment) 미존재는 정상 상태 — 404가 아니라 200 + null 필드로 응답한다
        # (설계 확정). 정답률 3개 필드는 분석 존재 여부와 무관하게 항상 실계산해서 채운다.
        return AnalysisResponse(
            set_id=material_set.id,
            weak_topics=None,
            comment=None,
            analyzed_at=None,
            total_attempts=total_attempts,
            correct_count=correct_count,
            overall_accuracy=overall_accuracy,
        )

    return AnalysisResponse(
        set_id=analysis.set_id,
        weak_topics=analysis.weak_topics,
        comment=analysis.comment,
        analyzed_at=analysis.analyzed_at,
        total_attempts=total_attempts,
        correct_count=correct_count,
        overall_accuracy=overall_accuracy,
    )


@router.get("/stats/summary", response_model=StatsSummaryResponse)
async def get_stats_summary(
    tz: str = Query(...),
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> StatsSummaryResponse:
    try:
        today = await db.scalar(select(cast(func.timezone(tz, func.now()), Date)))
    except DBAPIError as exc:
        raise AppError(400, "INVALID_TIMEZONE", f"유효하지 않은 시간대입니다: {tz}") from exc

    dismissed_dates_result = await db.execute(
        select(cast(func.timezone(tz, AlarmSession.dismissed_at), Date))
        .where(AlarmSession.user_id == user_id, AlarmSession.dismissed_at.isnot(None))
        .distinct()
    )
    dismissed_dates = {row[0] for row in dismissed_dates_result.all()}

    total_attempts, correct_attempts = (
        await db.execute(
            select(
                func.count(QuestionAttempt.id),
                func.count(QuestionAttempt.id).filter(QuestionAttempt.is_correct.is_(True)),
            )
            .join(AlarmSession, QuestionAttempt.session_id == AlarmSession.id)
            .where(AlarmSession.user_id == user_id)
        )
    ).one()
    correct_rate = round(100 * correct_attempts / total_attempts, 1) if total_attempts else 0.0

    total_sets = await db.scalar(select(func.count(MaterialSet.id)).where(MaterialSet.user_id == user_id))
    active_alarms = await db.scalar(
        select(func.count(Alarm.id)).where(Alarm.user_id == user_id, Alarm.is_enabled.is_(True))
    )

    return StatsSummaryResponse(
        current_streak=_compute_streak(dismissed_dates, today),
        total_study_days=len(dismissed_dates),
        total_attempts=total_attempts or 0,
        correct_rate=correct_rate,
        total_sets=total_sets or 0,
        active_alarms=active_alarms or 0,
    )
