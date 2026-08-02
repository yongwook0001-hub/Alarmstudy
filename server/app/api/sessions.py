from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, BackgroundTasks, Depends
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user_id, get_owned_session
from app.core.constants import BUFFER_LOW_THRESHOLD, REQUIRED_CORRECT_COUNT
from app.core.errors import AppError
from app.db.session import get_db
from app.models import Alarm, AlarmSession, MaterialSet, Question, QuestionAttempt, StudyMaterial, WrongAnswer
from app.services.analysis import update_weak_area_analysis
from app.services.generation_jobs import insert_job_if_absent

router = APIRouter()


# ---- schemas ---------------------------------------------------------------


class SessionStartRequest(BaseModel):
    alarm_id: int


class SessionQuestionOut(BaseModel):
    """정답 판정은 서버 책임 — correct_answer·explanation은 절대 포함하지 않는다."""

    question_id: int
    source: Literal["buffer", "retry"]
    content: str
    choices: list[str]
    topic: str


class SessionStartResponse(BaseModel):
    session_id: int
    required_count: int
    questions: list[SessionQuestionOut]


class AttemptRequest(BaseModel):
    question_id: int
    source: Literal["buffer", "retry"]
    selected_answer: int | None = None
    time_taken_seconds: int | None = None


class AttemptResponse(BaseModel):
    is_correct: bool
    correct_answer: int
    explanation: str | None


class DismissRequest(BaseModel):
    dismiss_method: Literal["quiz", "mission"]


# ---- routes ------------------------------------------------------------


@router.post("/sessions", response_model=SessionStartResponse, status_code=201)
async def start_session(
    body: SessionStartRequest,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> SessionStartResponse:
    alarm = await db.get(Alarm, body.alarm_id)
    if alarm is None or alarm.user_id != user_id:
        raise AppError(404, "ALARM_NOT_FOUND", "알람을 찾을 수 없습니다.")

    if alarm.set_id is None:
        raise AppError(409, "ALARM_HAS_NO_SET", "세트가 연결되지 않은 알람입니다.")

    set_id = alarm.set_id
    material_ids_subq = select(StudyMaterial.id).where(StudyMaterial.set_id == set_id)

    # 버퍼 우선 — 알람에 연결된 세트의 자료에 속한 문제만 대상으로 한다.
    buffer_result = await db.execute(
        select(Question)
        .where(Question.material_id.in_(material_ids_subq))
        .order_by(Question.created_at.asc(), Question.id.asc())
        .limit(REQUIRED_CORRECT_COUNT)
    )
    buffer_questions = list(buffer_result.scalars().all())

    # 부족분은 wrong_answers에서 last_wrong_at 오래된 순으로 채운다 (지연방지 폴백).
    remaining_needed = REQUIRED_CORRECT_COUNT - len(buffer_questions)
    retry_answers: list[WrongAnswer] = []
    if remaining_needed > 0:
        retry_result = await db.execute(
            select(WrongAnswer)
            .where(WrongAnswer.user_id == user_id, WrongAnswer.material_id.in_(material_ids_subq))
            .order_by(WrongAnswer.last_wrong_at.asc())
            .limit(remaining_needed)
        )
        retry_answers = list(retry_result.scalars().all())

    total_count = len(buffer_questions) + len(retry_answers)
    if total_count == 0:
        raise AppError(409, "NO_QUESTIONS_AVAILABLE", "출제할 수 있는 문제가 없습니다.")

    # required_count는 이 세션에 실제로 내려주는 문제 수를 스냅샷으로 저장한다 — 버퍼 부족으로
    # 조정된 값이라도 dismiss 시점에 전역 상수가 아니라 이 값 기준으로 검증해야 하기 때문이다.
    session = AlarmSession(
        user_id=user_id,
        alarm_id=alarm.id,
        started_at=datetime.now(timezone.utc),
        required_count=total_count,
    )
    db.add(session)
    await db.flush()

    # 잔여 버퍼 임계치 체크 — 이번 세션이 버퍼에서 실제로 가져간 만큼을 뺀 "남을" 수량 기준.
    total_buffer_count = await db.scalar(
        select(func.count(Question.id)).where(Question.material_id.in_(material_ids_subq))
    )
    remaining_buffer = (total_buffer_count or 0) - len(buffer_questions)
    if remaining_buffer < BUFFER_LOW_THRESHOLD:
        await insert_job_if_absent(db, set_id, "buffer_low")

    await db.commit()

    questions_out = [
        SessionQuestionOut(question_id=q.id, source="buffer", content=q.content, choices=q.choices, topic=q.topic)
        for q in buffer_questions
    ] + [
        SessionQuestionOut(question_id=w.id, source="retry", content=w.content, choices=w.choices, topic=w.topic)
        for w in retry_answers
    ]

    return SessionStartResponse(session_id=session.id, required_count=total_count, questions=questions_out)


@router.post("/sessions/{session_id}/attempts", response_model=AttemptResponse)
async def submit_attempt(
    body: AttemptRequest,
    session: AlarmSession = Depends(get_owned_session),
    db: AsyncSession = Depends(get_db),
) -> AttemptResponse:
    if session.dismissed_at is not None:
        raise AppError(409, "SESSION_ALREADY_DISMISSED", "이미 해제된 세션입니다.")

    if body.source == "buffer":
        question = await db.get(Question, body.question_id)
        if question is None:
            raise AppError(404, "QUESTION_NOT_FOUND", "문제를 찾을 수 없습니다 (이미 처리됨).")

        owner_id = await db.scalar(
            select(MaterialSet.user_id)
            .join(StudyMaterial, StudyMaterial.set_id == MaterialSet.id)
            .where(StudyMaterial.id == question.material_id)
        )
        if owner_id != session.user_id:
            raise AppError(404, "QUESTION_NOT_FOUND", "문제를 찾을 수 없습니다 (이미 처리됨).")

        is_correct = body.selected_answer is not None and body.selected_answer == question.correct_answer
        correct_answer, explanation = question.correct_answer, question.explanation

        db.add(
            QuestionAttempt(
                session_id=session.id,
                material_id=question.material_id,
                topic=question.topic,
                is_correct=is_correct,
                selected_answer=body.selected_answer,
                time_taken_seconds=body.time_taken_seconds,
                source="buffer",
            )
        )

        if not is_correct:
            # 오답 스냅샷을 wrong_answers로 이동 — questions는 삭제 후엔 흔적이 안 남으므로
            # 재출제 풀에 넣어줄 내용을 먼저 복사해둔다.
            db.add(
                WrongAnswer(
                    user_id=session.user_id,
                    material_id=question.material_id,
                    content=question.content,
                    choices=question.choices,
                    correct_answer=question.correct_answer,
                    explanation=question.explanation,
                    topic=question.topic,
                )
            )

        await db.delete(question)

    else:  # source == "retry"
        wrong_answer = await db.get(WrongAnswer, body.question_id)
        if wrong_answer is None or wrong_answer.user_id != session.user_id:
            raise AppError(404, "QUESTION_NOT_FOUND", "문제를 찾을 수 없습니다 (이미 처리됨).")

        is_correct = body.selected_answer is not None and body.selected_answer == wrong_answer.correct_answer
        correct_answer, explanation = wrong_answer.correct_answer, wrong_answer.explanation

        db.add(
            QuestionAttempt(
                session_id=session.id,
                material_id=wrong_answer.material_id,
                topic=wrong_answer.topic,
                is_correct=is_correct,
                selected_answer=body.selected_answer,
                time_taken_seconds=body.time_taken_seconds,
                source="retry",
            )
        )

        if is_correct:
            await db.delete(wrong_answer)  # 극복 — 재출제 풀에서 제거
        else:
            wrong_answer.wrong_count += 1
            wrong_answer.last_wrong_at = datetime.now(timezone.utc)

    await db.commit()

    return AttemptResponse(is_correct=is_correct, correct_answer=correct_answer, explanation=explanation)


@router.post("/sessions/{session_id}/dismiss")
async def dismiss_session(
    body: DismissRequest,
    background_tasks: BackgroundTasks,
    session: AlarmSession = Depends(get_owned_session),
    db: AsyncSession = Depends(get_db),
) -> dict:
    if session.dismissed_at is not None:
        return {}  # 멱등 — 이미 해제된 세션은 재검증 없이 그대로 200

    if body.dismiss_method == "quiz":
        correct_count = await db.scalar(
            select(func.count(QuestionAttempt.id)).where(
                QuestionAttempt.session_id == session.id,
                QuestionAttempt.is_correct.is_(True),
            )
        )
        if (correct_count or 0) < session.required_count:
            raise AppError(409, "QUIZ_NOT_COMPLETED", "정답 문제 수가 부족합니다.")
    # mission은 검증 없이 수용 — 모션 판정은 앱 로컬 책임.

    set_id = None
    if session.alarm_id is not None:
        set_id = await db.scalar(select(Alarm.set_id).where(Alarm.id == session.alarm_id))

    session.dismissed_at = datetime.now(timezone.utc)
    session.dismiss_method = body.dismiss_method
    await db.commit()

    if set_id is not None:
        background_tasks.add_task(update_weak_area_analysis, set_id)

    return {}
