import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.core.constants import BUFFER_LOW_THRESHOLD, REQUIRED_CORRECT_COUNT
from app.db.session import AsyncSessionLocal
from app.models import GenerationJob, Question, QuestionAttempt, StudyMaterial, WeakAreaAnalysis, WrongAnswer
from app.services.oauth import OAuthUserInfo

# ---- helpers ------------------------------------------------------------


class _FakeVerifier:
    def __init__(self, info: OAuthUserInfo) -> None:
        self._info = info

    async def verify(self, oauth_token: str) -> OAuthUserInfo:
        return self._info


async def _login(client, monkeypatch, provider_user_id: str = "sessions-test-uid"):
    info = OAuthUserInfo(provider_user_id=provider_user_id, nickname="세션테스터", email="session@example.com")
    monkeypatch.setattr("app.api.auth.get_oauth_verifier", lambda provider: _FakeVerifier(info))
    resp = await client.post("/api/auth/login", json={"provider": "google", "oauth_token": "irrelevant"})
    body = resp.json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


async def _create_set(client, headers, title: str = "세션 테스트 세트") -> int:
    resp = await client.post("/api/sets", json={"title": title}, headers=headers)
    return resp.json()["id"]


async def _create_alarm(client, headers, **overrides) -> int:
    payload = {"alarm_time": "07:00"}
    payload.update(overrides)
    resp = await client.post("/api/alarms", json=payload, headers=headers)
    return resp.json()["id"]


async def _insert_material(set_id: int, **overrides) -> int:
    defaults = dict(
        set_id=set_id,
        is_main=True,
        file_name="m.pdf",
        s3_key=f"sessions-test/{uuid.uuid4()}.pdf",
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


async def _insert_questions(material_id: int, count: int, correct_answer: int = 1, topic: str = "topic") -> list[int]:
    ids = []
    async with AsyncSessionLocal() as db:
        for i in range(count):
            question = Question(
                material_id=material_id,
                content=f"문제 {i}",
                choices=["a", "b", "c", "d"],
                correct_answer=correct_answer,
                explanation=f"설명 {i}",
                topic=topic,
            )
            db.add(question)
            await db.flush()
            ids.append(question.id)
        await db.commit()
    return ids


async def _insert_wrong_answer(user_id: int, material_id: int, last_wrong_at: datetime, **overrides) -> int:
    defaults = dict(
        user_id=user_id,
        material_id=material_id,
        content="오답 문제",
        choices=["a", "b", "c", "d"],
        correct_answer=2,
        explanation="오답 설명",
        topic="topic",
        last_wrong_at=last_wrong_at,
    )
    defaults.update(overrides)
    async with AsyncSessionLocal() as db:
        wrong_answer = WrongAnswer(**defaults)
        db.add(wrong_answer)
        await db.commit()
        await db.refresh(wrong_answer)
        return wrong_answer.id


async def _active_jobs(set_id: int) -> list[GenerationJob]:
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(GenerationJob).where(GenerationJob.set_id == set_id))
        return list(result.scalars().all())


async def _get_question(question_id: int) -> Question | None:
    async with AsyncSessionLocal() as db:
        return await db.get(Question, question_id)


async def _get_wrong_answer(wrong_answer_id: int) -> WrongAnswer | None:
    async with AsyncSessionLocal() as db:
        return await db.get(WrongAnswer, wrong_answer_id)


async def _wrong_answers_for_material(material_id: int) -> list[WrongAnswer]:
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(WrongAnswer).where(WrongAnswer.material_id == material_id))
        return list(result.scalars().all())


async def _attempts_for_session(session_id: int) -> list[QuestionAttempt]:
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(QuestionAttempt).where(QuestionAttempt.session_id == session_id))
        return list(result.scalars().all())


async def _get_analysis(set_id: int) -> WeakAreaAnalysis | None:
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(WeakAreaAnalysis).where(WeakAreaAnalysis.set_id == set_id))
        return result.scalar_one_or_none()


class _FixedCommentGenerator:
    def __init__(self, comment: str = "AI 코멘트") -> None:
        self._comment = comment

    async def generate(self, weak_topics: list[dict]) -> str:
        return self._comment


class _FailingCommentGenerator:
    async def generate(self, weak_topics: list[dict]) -> str:
        from app.services.analysis import AnalysisCommentError

        raise AnalysisCommentError("모의 AI 실패")


def _patch_comment_generator(monkeypatch, generator) -> None:
    monkeypatch.setattr("app.services.analysis._default_comment_generator", lambda: generator)


async def _setup_alarm_with_set(client, headers, **material_overrides) -> tuple[int, int, int]:
    """(alarm_id, set_id, material_id) 튜플을 반환하는 공통 셋업.

    알람은 is_enabled=False로 만든다 — 세션 API는 is_enabled를 보지 않지만, True로 만들면
    알람 생성 자체의 부수효과(POST /alarms의 'alarm_activated' job)가 세션 시작의
    'buffer_low' job과 같은 부분 UNIQUE(set_id)에 걸려 테스트를 오염시키기 때문이다.
    """
    set_id = await _create_set(client, headers)
    material_id = await _insert_material(set_id, **material_overrides)
    alarm_id = await _create_alarm(client, headers, set_id=set_id, is_enabled=False)
    return alarm_id, set_id, material_id


# ---- POST /api/sessions ------------------------------------------------------------


async def test_start_session_buffer_only_when_sufficient(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    await _insert_questions(material_id, REQUIRED_CORRECT_COUNT)

    resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)

    assert resp.status_code == 201
    body = resp.json()
    assert body["required_count"] == REQUIRED_CORRECT_COUNT
    assert len(body["questions"]) == REQUIRED_CORRECT_COUNT
    assert all(q["source"] == "buffer" for q in body["questions"])


async def test_start_session_response_never_leaks_correct_answer_or_explanation(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    await _insert_questions(material_id, 1)
    await _insert_wrong_answer(user_id, material_id, datetime.now(timezone.utc) - timedelta(days=1))

    resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)

    assert resp.status_code == 201
    for question in resp.json()["questions"]:
        assert "correct_answer" not in question
        assert "explanation" not in question
        assert set(question.keys()) == {"question_id", "source", "content", "choices", "topic"}


async def test_start_session_mixes_wrong_answers_ordered_by_oldest_last_wrong_at(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)

    buffer_count = max(REQUIRED_CORRECT_COUNT - 2, 0)
    await _insert_questions(material_id, buffer_count)

    now = datetime.now(timezone.utc)
    oldest_id = await _insert_wrong_answer(user_id, material_id, now - timedelta(days=5))
    middle_id = await _insert_wrong_answer(user_id, material_id, now - timedelta(days=3))
    await _insert_wrong_answer(user_id, material_id, now - timedelta(days=1))  # 가장 최신 — 뽑히면 안 됨

    resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)

    assert resp.status_code == 201
    body = resp.json()
    assert body["required_count"] == REQUIRED_CORRECT_COUNT
    retry_ids = [q["question_id"] for q in body["questions"] if q["source"] == "retry"]
    assert retry_ids == [oldest_id, middle_id]  # 오래된 순으로, 딱 부족분만큼만


async def test_start_session_adjusts_required_count_when_still_insufficient(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    await _insert_questions(material_id, 1)
    await _insert_wrong_answer(user_id, material_id, datetime.now(timezone.utc))

    resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)

    assert resp.status_code == 201
    body = resp.json()
    assert body["required_count"] == 2
    assert len(body["questions"]) == 2


async def test_start_session_no_questions_available_returns_409(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)

    resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)

    assert resp.status_code == 409
    assert resp.json()["error_code"] == "NO_QUESTIONS_AVAILABLE"


async def test_start_session_alarm_has_no_set_returns_409(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    alarm_id = await _create_alarm(client, headers)  # set_id 없음

    resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)

    assert resp.status_code == 409
    assert resp.json()["error_code"] == "ALARM_HAS_NO_SET"


async def test_start_session_alarm_not_found_returns_404(client, monkeypatch):
    headers_a, _ = await _login(client, monkeypatch, provider_user_id="sessions-owner-a")
    alarm_id = await _create_alarm(client, headers_a)

    headers_b, _ = await _login(client, monkeypatch, provider_user_id="sessions-owner-b")
    resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers_b)

    assert resp.status_code == 404
    assert resp.json()["error_code"] == "ALARM_NOT_FOUND"


async def test_start_session_creates_buffer_low_job_when_remaining_below_threshold(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    await _insert_questions(material_id, BUFFER_LOW_THRESHOLD + REQUIRED_CORRECT_COUNT - 1)

    resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)

    assert resp.status_code == 201
    jobs = await _active_jobs(set_id)
    assert len(jobs) == 1
    assert jobs[0].trigger_type == "buffer_low"


async def test_start_session_skips_buffer_low_job_when_remaining_at_threshold(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    await _insert_questions(material_id, BUFFER_LOW_THRESHOLD + REQUIRED_CORRECT_COUNT)

    resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)

    assert resp.status_code == 201
    assert await _active_jobs(set_id) == []


# ---- POST /api/sessions/{id}/attempts ------------------------------------------------------------


async def test_attempt_buffer_correct_deletes_question_no_wrong_answer(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    (question_id,) = await _insert_questions(material_id, 1, correct_answer=1)

    start_resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)
    session_id = start_resp.json()["session_id"]

    resp = await client.post(
        f"/api/sessions/{session_id}/attempts",
        json={"question_id": question_id, "source": "buffer", "selected_answer": 1, "time_taken_seconds": 7},
        headers=headers,
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body == {"is_correct": True, "correct_answer": 1, "explanation": "설명 0"}

    assert await _get_question(question_id) is None
    assert await _wrong_answers_for_material(material_id) == []

    attempts = await _attempts_for_session(session_id)
    assert len(attempts) == 1
    assert attempts[0].is_correct is True
    assert attempts[0].source == "buffer"
    assert attempts[0].material_id == material_id
    assert attempts[0].topic == "topic"
    assert attempts[0].selected_answer == 1
    assert attempts[0].time_taken_seconds == 7


async def test_attempt_buffer_incorrect_snapshots_to_wrong_answers_then_deletes_question(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    (question_id,) = await _insert_questions(material_id, 1, correct_answer=1)

    start_resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)
    session_id = start_resp.json()["session_id"]

    resp = await client.post(
        f"/api/sessions/{session_id}/attempts",
        json={"question_id": question_id, "source": "buffer", "selected_answer": 2},
        headers=headers,
    )

    assert resp.status_code == 200
    assert resp.json()["is_correct"] is False

    assert await _get_question(question_id) is None
    wrong_answers = await _wrong_answers_for_material(material_id)
    assert len(wrong_answers) == 1
    assert wrong_answers[0].wrong_count == 1
    assert wrong_answers[0].content == "문제 0"
    assert wrong_answers[0].topic == "topic"

    attempts = await _attempts_for_session(session_id)
    assert attempts[0].is_correct is False
    assert attempts[0].source == "buffer"


async def test_attempt_null_selected_answer_is_always_incorrect(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    (question_id,) = await _insert_questions(material_id, 1, correct_answer=1)

    start_resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)
    session_id = start_resp.json()["session_id"]

    resp = await client.post(
        f"/api/sessions/{session_id}/attempts",
        json={"question_id": question_id, "source": "buffer", "selected_answer": None},
        headers=headers,
    )

    assert resp.status_code == 200
    assert resp.json()["is_correct"] is False
    assert len(await _wrong_answers_for_material(material_id)) == 1


async def test_attempt_retry_correct_deletes_wrong_answer(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    wrong_answer_id = await _insert_wrong_answer(
        user_id, material_id, datetime.now(timezone.utc), correct_answer=2
    )

    start_resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)
    session_id = start_resp.json()["session_id"]

    resp = await client.post(
        f"/api/sessions/{session_id}/attempts",
        json={"question_id": wrong_answer_id, "source": "retry", "selected_answer": 2},
        headers=headers,
    )

    assert resp.status_code == 200
    assert resp.json()["is_correct"] is True
    assert await _get_wrong_answer(wrong_answer_id) is None  # 극복 → 삭제

    attempts = await _attempts_for_session(session_id)
    assert attempts[0].is_correct is True
    assert attempts[0].source == "retry"


async def test_attempt_retry_incorrect_increments_wrong_count_and_updates_last_wrong_at(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    old_last_wrong_at = datetime.now(timezone.utc) - timedelta(days=10)
    wrong_answer_id = await _insert_wrong_answer(user_id, material_id, old_last_wrong_at, correct_answer=2)

    start_resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)
    session_id = start_resp.json()["session_id"]

    resp = await client.post(
        f"/api/sessions/{session_id}/attempts",
        json={"question_id": wrong_answer_id, "source": "retry", "selected_answer": 0},
        headers=headers,
    )

    assert resp.status_code == 200
    assert resp.json()["is_correct"] is False

    wrong_answer = await _get_wrong_answer(wrong_answer_id)
    assert wrong_answer is not None
    assert wrong_answer.wrong_count == 2
    assert wrong_answer.last_wrong_at > old_last_wrong_at


async def test_attempt_already_processed_question_returns_404(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    (question_id,) = await _insert_questions(material_id, 1, correct_answer=1)

    start_resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)
    session_id = start_resp.json()["session_id"]

    first = await client.post(
        f"/api/sessions/{session_id}/attempts",
        json={"question_id": question_id, "source": "buffer", "selected_answer": 1},
        headers=headers,
    )
    second = await client.post(
        f"/api/sessions/{session_id}/attempts",
        json={"question_id": question_id, "source": "buffer", "selected_answer": 1},
        headers=headers,
    )

    assert first.status_code == 200
    assert second.status_code == 404
    assert second.json()["error_code"] == "QUESTION_NOT_FOUND"


async def test_attempt_other_users_question_is_hidden_as_404(client, monkeypatch):
    headers_a, _ = await _login(client, monkeypatch, provider_user_id="sessions-attempt-a")
    _, _, material_a = await _setup_alarm_with_set(client, headers_a)
    (question_id,) = await _insert_questions(material_a, 1, correct_answer=1)

    headers_b, _ = await _login(client, monkeypatch, provider_user_id="sessions-attempt-b")
    alarm_b, set_b, material_b = await _setup_alarm_with_set(client, headers_b)
    await _insert_questions(material_b, 1, correct_answer=1)
    start_resp = await client.post("/api/sessions", json={"alarm_id": alarm_b}, headers=headers_b)
    session_b = start_resp.json()["session_id"]

    resp = await client.post(
        f"/api/sessions/{session_b}/attempts",
        json={"question_id": question_id, "source": "buffer", "selected_answer": 1},
        headers=headers_b,
    )

    assert resp.status_code == 404
    assert resp.json()["error_code"] == "QUESTION_NOT_FOUND"


async def test_attempt_session_not_found_returns_404(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)

    resp = await client.post(
        "/api/sessions/999999/attempts",
        json={"question_id": 1, "source": "buffer", "selected_answer": 0},
        headers=headers,
    )

    assert resp.status_code == 404
    assert resp.json()["error_code"] == "SESSION_NOT_FOUND"


async def test_attempt_on_dismissed_session_returns_409(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    (question_id,) = await _insert_questions(material_id, 1, correct_answer=1)

    start_resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)
    session_id = start_resp.json()["session_id"]
    await client.post(f"/api/sessions/{session_id}/dismiss", json={"dismiss_method": "mission"}, headers=headers)

    resp = await client.post(
        f"/api/sessions/{session_id}/attempts",
        json={"question_id": question_id, "source": "buffer", "selected_answer": 1},
        headers=headers,
    )

    assert resp.status_code == 409
    assert resp.json()["error_code"] == "SESSION_ALREADY_DISMISSED"


# ---- POST /api/sessions/{id}/dismiss ------------------------------------------------------------


async def test_dismiss_quiz_insufficient_correct_returns_409(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    await _insert_questions(material_id, REQUIRED_CORRECT_COUNT)
    start_resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)
    session_id = start_resp.json()["session_id"]
    # 정답 attempts를 하나도 기록하지 않은 채 바로 dismiss 시도

    resp = await client.post(f"/api/sessions/{session_id}/dismiss", json={"dismiss_method": "quiz"}, headers=headers)

    assert resp.status_code == 409
    assert resp.json()["error_code"] == "QUIZ_NOT_COMPLETED"


async def test_dismiss_quiz_sufficient_correct_returns_200(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    question_ids = await _insert_questions(material_id, REQUIRED_CORRECT_COUNT, correct_answer=1)
    start_resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)
    session_id = start_resp.json()["session_id"]

    for question_id in question_ids:
        await client.post(
            f"/api/sessions/{session_id}/attempts",
            json={"question_id": question_id, "source": "buffer", "selected_answer": 1},
            headers=headers,
        )

    resp = await client.post(f"/api/sessions/{session_id}/dismiss", json={"dismiss_method": "quiz"}, headers=headers)

    assert resp.status_code == 200


async def test_dismiss_quiz_with_buffer_shortfall_uses_sessions_own_required_count(client, monkeypatch):
    """회귀 테스트: 세션 시작 시 문제가 부족해 required_count가 REQUIRED_CORRECT_COUNT보다
    작게 조정된 경우, dismiss의 quiz 검증은 그 조정된(세션에 저장된) 값을 기준으로 해야 한다.

    예전 버그: dismiss가 전역 상수(REQUIRED_CORRECT_COUNT)로 검증해서, 조정된 필요 정답 수를
    전부 맞혀도 항상 409 QUIZ_NOT_COMPLETED가 나 quiz로는 영원히 해제할 수 없었다.
    """
    shortfall_count = REQUIRED_CORRECT_COUNT - 1
    assert shortfall_count > 0  # 이 테스트가 성립하려면 상수가 최소 2 이상이어야 한다

    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    question_ids = await _insert_questions(material_id, shortfall_count, correct_answer=1)

    start_resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)
    assert start_resp.status_code == 201
    assert start_resp.json()["required_count"] == shortfall_count  # 조정됐는지 먼저 확인
    session_id = start_resp.json()["session_id"]

    for question_id in question_ids:
        await client.post(
            f"/api/sessions/{session_id}/attempts",
            json={"question_id": question_id, "source": "buffer", "selected_answer": 1},
            headers=headers,
        )

    resp = await client.post(f"/api/sessions/{session_id}/dismiss", json={"dismiss_method": "quiz"}, headers=headers)

    assert resp.status_code == 200


async def test_dismiss_quiz_with_buffer_shortfall_still_rejects_if_under_adjusted_count(client, monkeypatch):
    """위 회귀 테스트의 반대 케이스 — 조정된 required_count 자체도 충족하지 못하면
    여전히 409여야 한다 (검증이 아예 느슨해져 버린 게 아님을 확인)."""
    shortfall_count = REQUIRED_CORRECT_COUNT - 1
    assert shortfall_count > 0

    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    await _insert_questions(material_id, shortfall_count, correct_answer=1)

    start_resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)
    assert start_resp.json()["required_count"] == shortfall_count
    session_id = start_resp.json()["session_id"]
    # 정답 attempts를 하나도 기록하지 않은 채 바로 dismiss 시도

    resp = await client.post(f"/api/sessions/{session_id}/dismiss", json={"dismiss_method": "quiz"}, headers=headers)

    assert resp.status_code == 409
    assert resp.json()["error_code"] == "QUIZ_NOT_COMPLETED"


async def test_dismiss_mission_accepts_without_validation(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    await _insert_questions(material_id, 1)
    start_resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)
    session_id = start_resp.json()["session_id"]

    resp = await client.post(
        f"/api/sessions/{session_id}/dismiss", json={"dismiss_method": "mission"}, headers=headers
    )

    assert resp.status_code == 200


async def test_dismiss_is_idempotent(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    await _insert_questions(material_id, 1)
    start_resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)
    session_id = start_resp.json()["session_id"]

    first = await client.post(
        f"/api/sessions/{session_id}/dismiss", json={"dismiss_method": "mission"}, headers=headers
    )
    # 두 번째는 quiz로 보내도(원래라면 검증에 걸릴 수 있는 값) 멱등하게 200이어야 한다
    second = await client.post(f"/api/sessions/{session_id}/dismiss", json={"dismiss_method": "quiz"}, headers=headers)

    assert first.status_code == 200
    assert second.status_code == 200


async def test_dismiss_ownership_violation_returns_404(client, monkeypatch):
    headers_a, _ = await _login(client, monkeypatch, provider_user_id="dismiss-owner-a")
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers_a)
    await _insert_questions(material_id, 1)
    start_resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers_a)
    session_id = start_resp.json()["session_id"]

    headers_b, _ = await _login(client, monkeypatch, provider_user_id="dismiss-owner-b")
    resp = await client.post(
        f"/api/sessions/{session_id}/dismiss", json={"dismiss_method": "mission"}, headers=headers_b
    )

    assert resp.status_code == 404
    assert resp.json()["error_code"] == "SESSION_NOT_FOUND"


async def test_dismiss_success_updates_weak_area_analysis_via_background_task(client, monkeypatch):
    _patch_comment_generator(monkeypatch, _FixedCommentGenerator("AI 코멘트"))

    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)
    (question_id,) = await _insert_questions(material_id, 1, correct_answer=1, topic="이진트리")
    start_resp = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)
    session_id = start_resp.json()["session_id"]

    await client.post(
        f"/api/sessions/{session_id}/attempts",
        json={"question_id": question_id, "source": "buffer", "selected_answer": 1},
        headers=headers,
    )
    resp = await client.post(
        f"/api/sessions/{session_id}/dismiss", json={"dismiss_method": "mission"}, headers=headers
    )

    assert resp.status_code == 200
    # ASGITransport는 BackgroundTasks까지 끝난 뒤에 응답을 돌려주므로 이 시점에 이미 갱신돼 있다.
    analysis = await _get_analysis(set_id)
    assert analysis is not None
    assert analysis.comment == "AI 코멘트"
    assert analysis.weak_topics == [{"topic": "이진트리", "accuracy": 100}]


async def test_dismiss_ai_failure_preserves_comment_across_two_sessions(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    alarm_id, set_id, material_id = await _setup_alarm_with_set(client, headers)

    _patch_comment_generator(monkeypatch, _FixedCommentGenerator("보존되어야 할 코멘트"))
    (first_question_id,) = await _insert_questions(material_id, 1, correct_answer=1, topic="순회")
    start1 = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)
    session1 = start1.json()["session_id"]
    await client.post(
        f"/api/sessions/{session1}/attempts",
        json={"question_id": first_question_id, "source": "buffer", "selected_answer": 1},
        headers=headers,
    )
    await client.post(f"/api/sessions/{session1}/dismiss", json={"dismiss_method": "mission"}, headers=headers)
    assert (await _get_analysis(set_id)).comment == "보존되어야 할 코멘트"

    _patch_comment_generator(monkeypatch, _FailingCommentGenerator())
    (second_question_id,) = await _insert_questions(material_id, 1, correct_answer=1, topic="탐색")
    start2 = await client.post("/api/sessions", json={"alarm_id": alarm_id}, headers=headers)
    session2 = start2.json()["session_id"]
    await client.post(
        f"/api/sessions/{session2}/attempts",
        json={"question_id": second_question_id, "source": "buffer", "selected_answer": 1},
        headers=headers,
    )
    resp = await client.post(f"/api/sessions/{session2}/dismiss", json={"dismiss_method": "mission"}, headers=headers)

    assert resp.status_code == 200
    analysis = await _get_analysis(set_id)
    assert analysis.comment == "보존되어야 할 코멘트"  # AI 실패에도 이전 값 유지
    topics = {item["topic"]: item["accuracy"] for item in analysis.weak_topics}
    assert topics == {"순회": 100, "탐색": 100}
