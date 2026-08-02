import re
from datetime import datetime
from datetime import time as dt_time

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user_id, get_owned_alarm
from app.core.constants import BUFFER_TARGET_PER_SET
from app.core.errors import AppError
from app.db.session import get_db
from app.models import Alarm, MaterialSet, Question, StudyMaterial
from app.services.generation_jobs import insert_job_if_absent

router = APIRouter()

_ALARM_TIME_PATTERN = re.compile(r"^([01]\d|2[0-3]):([0-5]\d)$")


# ---- schemas ---------------------------------------------------------------


class AlarmCreateRequest(BaseModel):
    alarm_time: str
    set_id: int | None = None
    repeat_days: int | None = None
    is_enabled: bool | None = None
    label: str | None = None
    sound: str | None = None
    volume: int | None = None
    is_vibration: bool | None = None


class AlarmPatchRequest(BaseModel):
    set_id: int | None = None
    alarm_time: str | None = None
    repeat_days: int | None = None
    is_enabled: bool | None = None
    label: str | None = None
    sound: str | None = None
    volume: int | None = None
    is_vibration: bool | None = None


class AlarmOut(BaseModel):
    id: int
    set_id: int | None
    set_title: str | None
    alarm_time: str
    repeat_days: int
    is_enabled: bool
    label: str | None
    sound: str
    volume: int
    is_vibration: bool
    created_at: datetime
    updated_at: datetime


# ---- helpers ------------------------------------------------------------


def _parse_alarm_time(value: str) -> dt_time:
    match = _ALARM_TIME_PATTERN.match(value)
    if match is None:
        raise AppError(400, "INVALID_ALARM_TIME", "alarm_time은 HH:MM 형식이어야 합니다.")
    return dt_time(int(match.group(1)), int(match.group(2)))


def _to_alarm_out(alarm: Alarm, set_title: str | None) -> AlarmOut:
    return AlarmOut(
        id=alarm.id,
        set_id=alarm.set_id,
        set_title=set_title,
        alarm_time=alarm.alarm_time.strftime("%H:%M"),
        repeat_days=alarm.repeat_days,
        is_enabled=alarm.is_enabled,
        label=alarm.label,
        sound=alarm.sound,
        volume=alarm.volume,
        is_vibration=alarm.is_vibration,
        created_at=alarm.created_at,
        updated_at=alarm.updated_at,
    )


async def _insert_job_if_buffer_below_target(db: AsyncSession, set_id: int, trigger_type: str) -> None:
    current_count = await db.scalar(
        select(func.count(Question.id))
        .join(StudyMaterial, Question.material_id == StudyMaterial.id)
        .where(StudyMaterial.set_id == set_id)
    )
    if (current_count or 0) < BUFFER_TARGET_PER_SET:
        await insert_job_if_absent(db, set_id, trigger_type)


async def _cleanup_buffer_if_orphaned(db: AsyncSession, set_id: int) -> None:
    """세트에 연결된 알람이 하나도 안 남았으면(비활성 포함 0개) 버퍼(questions)를 지운다.
    wrong_answers는 건드리지 않는다 — 오답은 재출제서 정답을 맞혀야만 삭제된다 (설계 확정)."""
    remaining = await db.scalar(select(func.count(Alarm.id)).where(Alarm.set_id == set_id))
    if remaining == 0:
        await db.execute(
            delete(Question).where(
                Question.material_id.in_(select(StudyMaterial.id).where(StudyMaterial.set_id == set_id))
            )
        )


# ---- routes ------------------------------------------------------------


@router.post("/alarms", response_model=AlarmOut, status_code=201)
async def create_alarm(
    body: AlarmCreateRequest,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AlarmOut:
    alarm_time = _parse_alarm_time(body.alarm_time)

    if body.set_id is not None:
        material_set = await db.get(MaterialSet, body.set_id)
        if material_set is None or material_set.user_id != user_id:
            raise AppError(404, "SET_NOT_FOUND", "세트를 찾을 수 없습니다.")

    # alarm_time·set_id는 위에서 이미 처리했으니 제외하고, 클라이언트가 실제로 보낸
    # 필드만 넘긴다 — 나머지는 파이썬 쪽 속성 자체를 건드리지 않아 DB default가 적용된다.
    extra_fields = body.model_dump(exclude_unset=True, exclude={"alarm_time", "set_id"})
    alarm = Alarm(user_id=user_id, alarm_time=alarm_time, set_id=body.set_id, **extra_fields)
    db.add(alarm)
    await db.flush()
    await db.refresh(alarm)  # is_enabled 등 DB default를 반영해야 아래 조건을 정확히 판단할 수 있다

    if alarm.is_enabled and alarm.set_id is not None:
        await insert_job_if_absent(db, alarm.set_id, "alarm_activated")

    await db.commit()

    set_title = None
    if alarm.set_id is not None:
        set_title = await db.scalar(select(MaterialSet.title).where(MaterialSet.id == alarm.set_id))

    return _to_alarm_out(alarm, set_title)


@router.get("/alarms", response_model=list[AlarmOut])
async def list_alarms(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> list[AlarmOut]:
    result = await db.execute(
        select(Alarm, MaterialSet.title)
        .outerjoin(MaterialSet, Alarm.set_id == MaterialSet.id)
        .where(Alarm.user_id == user_id)
        .order_by(Alarm.created_at.desc())
    )
    return [_to_alarm_out(alarm, set_title) for alarm, set_title in result.all()]


@router.patch("/alarms/{alarm_id}", response_model=AlarmOut)
async def update_alarm(
    body: AlarmPatchRequest,
    alarm: Alarm = Depends(get_owned_alarm),
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AlarmOut:
    provided = body.model_dump(exclude_unset=True)

    new_set_id = provided.get("set_id", alarm.set_id)
    if "set_id" in provided and new_set_id is not None:
        material_set = await db.get(MaterialSet, new_set_id)
        if material_set is None or material_set.user_id != user_id:
            raise AppError(404, "SET_NOT_FOUND", "세트를 찾을 수 없습니다.")

    new_alarm_time = _parse_alarm_time(provided["alarm_time"]) if "alarm_time" in provided else None

    previous_set_id = alarm.set_id
    previous_is_enabled = alarm.is_enabled

    if new_alarm_time is not None:
        alarm.alarm_time = new_alarm_time
    if "set_id" in provided:
        alarm.set_id = new_set_id
    for field in ("repeat_days", "is_enabled", "label", "sound", "volume", "is_vibration"):
        if field in provided:
            setattr(alarm, field, provided[field])

    set_id_changed = alarm.set_id != previous_set_id
    became_enabled = (not previous_is_enabled) and alarm.is_enabled

    # 아래 세 갈래는 서로 독립적인 부수효과 규칙이다 (한 PATCH에서 여러 개가 동시에 맞아도
    # 무방 — job 생성은 ON CONFLICT DO NOTHING으로 중복에 안전하다).
    if set_id_changed and previous_set_id is not None:
        await _cleanup_buffer_if_orphaned(db, previous_set_id)
    if set_id_changed and alarm.set_id is not None:
        await insert_job_if_absent(db, alarm.set_id, "alarm_activated")
    if became_enabled and alarm.set_id is not None:
        await _insert_job_if_buffer_below_target(db, alarm.set_id, "reactivated")

    await db.commit()
    await db.refresh(alarm)

    set_title = None
    if alarm.set_id is not None:
        set_title = await db.scalar(select(MaterialSet.title).where(MaterialSet.id == alarm.set_id))

    return _to_alarm_out(alarm, set_title)


@router.delete("/alarms/{alarm_id}")
async def delete_alarm(
    alarm: Alarm = Depends(get_owned_alarm),
    db: AsyncSession = Depends(get_db),
) -> dict:
    set_id = alarm.set_id
    await db.delete(alarm)

    if set_id is not None:
        await _cleanup_buffer_if_orphaned(db, set_id)

    await db.commit()
    return {}
