import uuid
from datetime import datetime, timezone

from sqlalchemy import func, select

from app.core.constants import BUFFER_TARGET_PER_SET
from app.db.session import AsyncSessionLocal
from app.models import AlarmSession, GenerationJob, Question, StudyMaterial, WrongAnswer
from app.services.oauth import OAuthUserInfo

# ---- helpers ------------------------------------------------------------


class _FakeVerifier:
    def __init__(self, info: OAuthUserInfo) -> None:
        self._info = info

    async def verify(self, oauth_token: str) -> OAuthUserInfo:
        return self._info


async def _login(client, monkeypatch, provider_user_id: str = "alarms-test-uid"):
    info = OAuthUserInfo(provider_user_id=provider_user_id, nickname="알람테스터", email="alarm@example.com")
    monkeypatch.setattr("app.api.auth.get_oauth_verifier", lambda provider: _FakeVerifier(info))
    resp = await client.post("/api/auth/login", json={"provider": "google", "oauth_token": "irrelevant"})
    body = resp.json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


async def _create_set(client, headers, title: str = "알람 테스트 세트") -> int:
    resp = await client.post("/api/sets", json={"title": title}, headers=headers)
    return resp.json()["id"]


async def _insert_material(set_id: int, **overrides) -> int:
    defaults = dict(
        set_id=set_id,
        is_main=True,
        file_name="m.pdf",
        s3_key=f"alarms-test/{uuid.uuid4()}.pdf",
        file_size_bytes=1,
        upload_status="ready",
    )
    defaults.update(overrides)
    async with AsyncSessionLocal() as db:
        material = StudyMaterial(**defaults)
        db.add(material)
        await db.commit()
        await db.refresh(material)
        return material.id


async def _insert_questions(material_id: int, count: int) -> None:
    async with AsyncSessionLocal() as db:
        for i in range(count):
            db.add(
                Question(
                    material_id=material_id,
                    content=f"문제 {i}",
                    choices=["a", "b", "c", "d"],
                    correct_answer=0,
                    topic="topic",
                )
            )
        await db.commit()


async def _insert_wrong_answer(user_id: int, material_id: int) -> int:
    async with AsyncSessionLocal() as db:
        wrong_answer = WrongAnswer(
            user_id=user_id,
            material_id=material_id,
            content="오답 문제",
            choices=["a", "b", "c", "d"],
            correct_answer=0,
            topic="topic",
        )
        db.add(wrong_answer)
        await db.commit()
        await db.refresh(wrong_answer)
        return wrong_answer.id


async def _insert_alarm_session(user_id: int, alarm_id: int) -> int:
    async with AsyncSessionLocal() as db:
        session_row = AlarmSession(user_id=user_id, alarm_id=alarm_id, started_at=datetime.now(timezone.utc))
        db.add(session_row)
        await db.commit()
        await db.refresh(session_row)
        return session_row.id


async def _get_alarm_session(session_id: int) -> AlarmSession | None:
    async with AsyncSessionLocal() as db:
        return await db.get(AlarmSession, session_id)


async def _active_jobs(set_id: int) -> list[GenerationJob]:
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(GenerationJob).where(GenerationJob.set_id == set_id))
        return list(result.scalars().all())


async def _question_count(material_id: int) -> int:
    async with AsyncSessionLocal() as db:
        return await db.scalar(select(func.count(Question.id)).where(Question.material_id == material_id))


async def _wrong_answer_count(material_id: int) -> int:
    async with AsyncSessionLocal() as db:
        return await db.scalar(select(func.count(WrongAnswer.id)).where(WrongAnswer.material_id == material_id))


async def _create_alarm(client, headers, **overrides) -> dict:
    payload = {"alarm_time": "07:30"}
    payload.update(overrides)
    resp = await client.post("/api/alarms", json=payload, headers=headers)
    return resp


# ---- POST /api/alarms ------------------------------------------------------------


async def test_post_alarm_minimal_uses_db_defaults(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)

    resp = await _create_alarm(client, headers, alarm_time="07:05")

    assert resp.status_code == 201
    body = resp.json()
    assert body["alarm_time"] == "07:05"
    assert body["set_id"] is None
    assert body["set_title"] is None
    assert body["repeat_days"] == 0
    assert body["is_enabled"] is True
    assert body["sound"] == "default"
    assert body["volume"] == 80
    assert body["is_vibration"] is True


async def test_post_alarm_invalid_time_format(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)

    resp = await _create_alarm(client, headers, alarm_time="7:30")  # 0 패딩 없음 → 형식 오류

    assert resp.status_code == 400
    assert resp.json()["error_code"] == "INVALID_ALARM_TIME"


async def test_post_alarm_set_not_found(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)

    resp = await _create_alarm(client, headers, set_id=999_999)

    assert resp.status_code == 404
    assert resp.json()["error_code"] == "SET_NOT_FOUND"


async def test_post_alarm_repeat_days_passthrough_as_raw_bitmask(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)

    resp = await _create_alarm(client, headers, repeat_days=21)  # 0b0010101 — 변환 없이 그대로

    assert resp.status_code == 201
    assert resp.json()["repeat_days"] == 21


async def test_post_alarm_enabled_with_set_creates_generation_job(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)

    resp = await _create_alarm(client, headers, set_id=set_id)

    assert resp.status_code == 201
    body = resp.json()
    assert body["set_id"] == set_id
    assert body["set_title"] == "알람 테스트 세트"

    jobs = await _active_jobs(set_id)
    assert len(jobs) == 1
    assert jobs[0].trigger_type == "alarm_activated"
    assert jobs[0].status == "pending"


async def test_post_alarm_disabled_does_not_create_job(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)

    resp = await _create_alarm(client, headers, set_id=set_id, is_enabled=False)

    assert resp.status_code == 201
    assert await _active_jobs(set_id) == []


async def test_post_alarm_duplicate_job_is_silently_skipped(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)

    first = await _create_alarm(client, headers, set_id=set_id, alarm_time="07:00")
    second = await _create_alarm(client, headers, set_id=set_id, alarm_time="08:00")

    assert first.status_code == 201
    assert second.status_code == 201  # 알람 생성 자체는 성공 — job 중복만 조용히 스킵된다

    jobs = await _active_jobs(set_id)
    assert len(jobs) == 1


# ---- GET /api/alarms ------------------------------------------------------------


async def test_list_alarms_returns_all_with_set_title_and_only_own(client, monkeypatch):
    headers_a, _ = await _login(client, monkeypatch, provider_user_id="alarms-list-a")
    set_id = await _create_set(client, headers_a, title="목록용 세트")
    await _create_alarm(client, headers_a, set_id=set_id, alarm_time="06:00")
    await _create_alarm(client, headers_a, alarm_time="09:00")  # 일반 알람(세트 없음)

    headers_b, _ = await _login(client, monkeypatch, provider_user_id="alarms-list-b")
    await _create_alarm(client, headers_b, alarm_time="10:00")

    resp = await client.get("/api/alarms", headers=headers_a)

    assert resp.status_code == 200
    items = resp.json()
    assert len(items) == 2
    by_time = {item["alarm_time"]: item for item in items}
    assert by_time["06:00"]["set_title"] == "목록용 세트"
    assert by_time["09:00"]["set_id"] is None
    assert by_time["09:00"]["set_title"] is None


# ---- PATCH /api/alarms/{id} ------------------------------------------------------------


async def test_patch_ownership_violation_returns_404(client, monkeypatch):
    headers_a, _ = await _login(client, monkeypatch, provider_user_id="patch-owner-a")
    created = await _create_alarm(client, headers_a)
    alarm_id = created.json()["id"]

    headers_b, _ = await _login(client, monkeypatch, provider_user_id="patch-owner-b")
    resp = await client.patch(f"/api/alarms/{alarm_id}", json={"label": "훔친 라벨"}, headers=headers_b)

    assert resp.status_code == 404
    assert resp.json()["error_code"] == "ALARM_NOT_FOUND"


async def test_patch_invalid_alarm_time(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    created = await _create_alarm(client, headers)
    alarm_id = created.json()["id"]

    resp = await client.patch(f"/api/alarms/{alarm_id}", json={"alarm_time": "99:99"}, headers=headers)

    assert resp.status_code == 400
    assert resp.json()["error_code"] == "INVALID_ALARM_TIME"


async def test_patch_set_id_not_found(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    created = await _create_alarm(client, headers)
    alarm_id = created.json()["id"]

    resp = await client.patch(f"/api/alarms/{alarm_id}", json={"set_id": 999_999}, headers=headers)

    assert resp.status_code == 404
    assert resp.json()["error_code"] == "SET_NOT_FOUND"


async def test_patch_reactivation_creates_job_when_buffer_below_target(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)
    material_id = await _insert_material(set_id)
    await _insert_questions(material_id, 3)  # BUFFER_TARGET_PER_SET(20)에 크게 못 미침

    created = await _create_alarm(client, headers, set_id=set_id, is_enabled=False)
    alarm_id = created.json()["id"]
    assert await _active_jobs(set_id) == []  # 비활성으로 만들었으니 POST 시점엔 job 없음

    resp = await client.patch(f"/api/alarms/{alarm_id}", json={"is_enabled": True}, headers=headers)

    assert resp.status_code == 200
    assert resp.json()["is_enabled"] is True
    jobs = await _active_jobs(set_id)
    assert len(jobs) == 1
    assert jobs[0].trigger_type == "reactivated"


async def test_patch_reactivation_skips_job_when_buffer_already_full(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)
    material_id = await _insert_material(set_id)
    await _insert_questions(material_id, BUFFER_TARGET_PER_SET)  # 이미 목표 충족

    created = await _create_alarm(client, headers, set_id=set_id, is_enabled=False)
    alarm_id = created.json()["id"]

    resp = await client.patch(f"/api/alarms/{alarm_id}", json={"is_enabled": True}, headers=headers)

    assert resp.status_code == 200
    assert await _active_jobs(set_id) == []


async def test_patch_is_enabled_true_to_false_has_no_side_effect_buffer_preserved(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)
    material_id = await _insert_material(set_id)
    await _insert_questions(material_id, 5)

    created = await _create_alarm(client, headers, set_id=set_id, is_enabled=True)
    alarm_id = created.json()["id"]

    resp = await client.patch(f"/api/alarms/{alarm_id}", json={"is_enabled": False}, headers=headers)

    assert resp.status_code == 200
    assert resp.json()["is_enabled"] is False
    assert await _question_count(material_id) == 5  # 버퍼 그대로 유지


async def test_patch_set_id_change_creates_job_for_new_set_and_clears_orphaned_old_set_buffer(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_a = await _create_set(client, headers, title="세트 A")
    set_b = await _create_set(client, headers, title="세트 B")
    material_a = await _insert_material(set_a)
    await _insert_questions(material_a, 5)

    created = await _create_alarm(client, headers, set_id=set_a, is_enabled=True)
    alarm_id = created.json()["id"]

    resp = await client.patch(f"/api/alarms/{alarm_id}", json={"set_id": set_b}, headers=headers)

    assert resp.status_code == 200
    body = resp.json()
    assert body["set_id"] == set_b
    assert body["set_title"] == "세트 B"

    # 세트 A에 연결된 알람이 이제 0개 → 버퍼(questions) 삭제
    assert await _question_count(material_a) == 0
    # 세트 B는 새로 연결됐으니 job이 생성된다
    jobs_b = await _active_jobs(set_b)
    assert len(jobs_b) == 1
    assert jobs_b[0].trigger_type == "alarm_activated"


async def test_patch_set_id_change_keeps_old_set_buffer_when_disabled_alarm_still_connected(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_a = await _create_set(client, headers, title="세트 A")
    set_b = await _create_set(client, headers, title="세트 B")
    material_a = await _insert_material(set_a)
    await _insert_questions(material_a, 5)

    moving = await _create_alarm(client, headers, set_id=set_a, is_enabled=True)
    moving_id = moving.json()["id"]
    # 비활성이어도 "연결"로 카운트된다 (설계 확정: 비활성 포함)
    await _create_alarm(client, headers, set_id=set_a, is_enabled=False, alarm_time="11:00")

    resp = await client.patch(f"/api/alarms/{moving_id}", json={"set_id": set_b}, headers=headers)

    assert resp.status_code == 200
    assert await _question_count(material_a) == 5  # 아직 비활성 알람이 A를 붙잡고 있어 유지


async def test_patch_repeat_days_passthrough_as_raw_bitmask(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    created = await _create_alarm(client, headers)
    alarm_id = created.json()["id"]

    resp = await client.patch(f"/api/alarms/{alarm_id}", json={"repeat_days": 99}, headers=headers)

    assert resp.status_code == 200
    assert resp.json()["repeat_days"] == 99


# ---- DELETE /api/alarms/{id} ------------------------------------------------------------


async def test_delete_ownership_violation_returns_404(client, monkeypatch):
    headers_a, _ = await _login(client, monkeypatch, provider_user_id="delete-owner-a")
    created = await _create_alarm(client, headers_a)
    alarm_id = created.json()["id"]

    headers_b, _ = await _login(client, monkeypatch, provider_user_id="delete-owner-b")
    resp = await client.delete(f"/api/alarms/{alarm_id}", headers=headers_b)

    assert resp.status_code == 404
    assert resp.json()["error_code"] == "ALARM_NOT_FOUND"


async def test_delete_general_alarm_without_set_has_no_side_effect(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    created = await _create_alarm(client, headers)  # set_id 없음
    alarm_id = created.json()["id"]

    resp = await client.delete(f"/api/alarms/{alarm_id}", headers=headers)

    assert resp.status_code == 200


async def test_delete_last_connected_alarm_deletes_questions_but_keeps_wrong_answers(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)
    material_id = await _insert_material(set_id)
    await _insert_questions(material_id, 4)
    await _insert_wrong_answer(user_id, material_id)

    created = await _create_alarm(client, headers, set_id=set_id, is_enabled=True)
    alarm_id = created.json()["id"]

    resp = await client.delete(f"/api/alarms/{alarm_id}", headers=headers)

    assert resp.status_code == 200
    assert await _question_count(material_id) == 0
    assert await _wrong_answer_count(material_id) == 1  # 오답노트는 그대로 보존


async def test_delete_keeps_buffer_when_another_disabled_alarm_still_connected(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)
    material_id = await _insert_material(set_id)
    await _insert_questions(material_id, 4)

    first = await _create_alarm(client, headers, set_id=set_id, is_enabled=True, alarm_time="06:00")
    second = await _create_alarm(client, headers, set_id=set_id, is_enabled=False, alarm_time="07:00")
    first_id, second_id = first.json()["id"], second.json()["id"]

    resp = await client.delete(f"/api/alarms/{first_id}", headers=headers)
    assert resp.status_code == 200
    assert await _question_count(material_id) == 4  # 비활성 alarm이 여전히 세트를 붙잡고 있다

    resp2 = await client.delete(f"/api/alarms/{second_id}", headers=headers)
    assert resp2.status_code == 200
    assert await _question_count(material_id) == 0  # 이제 진짜 마지막 알람이 삭제됐다


async def test_delete_alarm_preserves_alarm_sessions_via_set_null(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    created = await _create_alarm(client, headers)
    alarm_id = created.json()["id"]
    session_id = await _insert_alarm_session(user_id, alarm_id)

    resp = await client.delete(f"/api/alarms/{alarm_id}", headers=headers)

    assert resp.status_code == 200
    session_row = await _get_alarm_session(session_id)
    assert session_row is not None
    assert session_row.alarm_id is None
