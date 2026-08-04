import uuid
from datetime import datetime, timedelta, timezone

from app.core.constants import REQUIRED_CORRECT_COUNT
from app.db.session import AsyncSessionLocal
from app.models import AlarmSession, QuestionAttempt, StudyMaterial, WeakAreaAnalysis, WrongAnswer
from app.services.oauth import OAuthUserInfo

# ---- helpers ------------------------------------------------------------


class _FakeVerifier:
    def __init__(self, info: OAuthUserInfo) -> None:
        self._info = info

    async def verify(self, oauth_token: str) -> OAuthUserInfo:
        return self._info


async def _login(client, monkeypatch, provider_user_id: str = "stats-test-uid"):
    info = OAuthUserInfo(provider_user_id=provider_user_id, nickname="통계테스터", email="stats@example.com")
    monkeypatch.setattr("app.api.auth.get_oauth_verifier", lambda provider: _FakeVerifier(info))
    resp = await client.post("/api/auth/login", json={"provider": "google", "oauth_token": "irrelevant"})
    body = resp.json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


async def _create_set(client, headers, title: str = "통계 테스트 세트") -> int:
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
        s3_key=f"stats-test/{uuid.uuid4()}.pdf",
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


async def _insert_wrong_answer(user_id: int, material_id: int, **overrides) -> int:
    defaults = dict(
        user_id=user_id,
        material_id=material_id,
        content="오답 문제",
        choices=["a", "b", "c", "d"],
        correct_answer=2,
        explanation="오답 설명",
        topic="topic",
        wrong_count=1,
        last_wrong_at=datetime.now(timezone.utc),
    )
    defaults.update(overrides)
    async with AsyncSessionLocal() as db:
        wrong_answer = WrongAnswer(**defaults)
        db.add(wrong_answer)
        await db.commit()
        await db.refresh(wrong_answer)
        return wrong_answer.id


async def _insert_analysis(set_id: int, user_id: int, **overrides) -> None:
    defaults = dict(
        user_id=user_id,
        set_id=set_id,
        weak_topics=[{"topic": "순회", "accuracy": 40}],
        comment="분석 코멘트",
        analyzed_at=datetime.now(timezone.utc),
    )
    defaults.update(overrides)
    async with AsyncSessionLocal() as db:
        db.add(WeakAreaAnalysis(**defaults))
        await db.commit()


async def _seed_dismissed_session(user_id: int, dismissed_at: datetime) -> int:
    async with AsyncSessionLocal() as db:
        session_row = AlarmSession(
            user_id=user_id,
            alarm_id=None,
            started_at=dismissed_at,
            required_count=REQUIRED_CORRECT_COUNT,
            dismissed_at=dismissed_at,
            dismiss_method="mission",
        )
        db.add(session_row)
        await db.commit()
        await db.refresh(session_row)
        return session_row.id


async def _seed_attempt(session_id: int, is_correct: bool, material_id: int | None = None, topic: str = "topic") -> None:
    async with AsyncSessionLocal() as db:
        db.add(
            QuestionAttempt(
                session_id=session_id,
                material_id=material_id,
                topic=topic,
                is_correct=is_correct,
                source="buffer",
            )
        )
        await db.commit()


# ---- GET /api/wrong-answers ------------------------------------------------------------


async def test_wrong_answers_sort_recent_defaults_to_last_wrong_at_desc(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)
    material_id = await _insert_material(set_id)
    now = datetime.now(timezone.utc)
    oldest = await _insert_wrong_answer(user_id, material_id, last_wrong_at=now - timedelta(days=3))
    newest = await _insert_wrong_answer(user_id, material_id, last_wrong_at=now - timedelta(days=1))
    middle = await _insert_wrong_answer(user_id, material_id, last_wrong_at=now - timedelta(days=2))

    resp = await client.get("/api/wrong-answers", headers=headers)

    assert resp.status_code == 200
    body = resp.json()
    assert [item["id"] for item in body["items"]] == [newest, middle, oldest]
    assert body["total"] == 3
    assert body["page"] == 1
    assert body["size"] == 20


async def test_wrong_answers_sort_most_wrong_desc(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)
    material_id = await _insert_material(set_id)
    low = await _insert_wrong_answer(user_id, material_id, wrong_count=1)
    high = await _insert_wrong_answer(user_id, material_id, wrong_count=5)
    mid = await _insert_wrong_answer(user_id, material_id, wrong_count=3)

    resp = await client.get("/api/wrong-answers", params={"sort": "most_wrong"}, headers=headers)

    assert resp.status_code == 200
    assert [item["id"] for item in resp.json()["items"]] == [high, mid, low]


async def test_wrong_answers_filters_by_set_id(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    set_a = await _create_set(client, headers, title="세트 A")
    set_b = await _create_set(client, headers, title="세트 B")
    material_a = await _insert_material(set_a)
    material_b = await _insert_material(set_b)
    wa_a = await _insert_wrong_answer(user_id, material_a)
    await _insert_wrong_answer(user_id, material_b)

    resp = await client.get("/api/wrong-answers", params={"set_id": set_a}, headers=headers)

    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 1
    assert body["items"][0]["id"] == wa_a


async def test_wrong_answers_filters_by_topic(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)
    material_id = await _insert_material(set_id)
    wa_matching = await _insert_wrong_answer(user_id, material_id, topic="이진트리")
    await _insert_wrong_answer(user_id, material_id, topic="그래프")

    resp = await client.get("/api/wrong-answers", params={"topic": "이진트리"}, headers=headers)

    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 1
    assert body["items"][0]["id"] == wa_matching


async def test_wrong_answers_pagination_boundaries(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)
    material_id = await _insert_material(set_id)
    now = datetime.now(timezone.utc)
    for i in range(5):
        await _insert_wrong_answer(user_id, material_id, last_wrong_at=now - timedelta(days=i))

    page1 = await client.get("/api/wrong-answers", params={"page": 1, "size": 2}, headers=headers)
    page3 = await client.get("/api/wrong-answers", params={"page": 3, "size": 2}, headers=headers)  # 마지막 페이지(1개)
    page4 = await client.get("/api/wrong-answers", params={"page": 4, "size": 2}, headers=headers)  # 범위 밖(빈 결과)

    assert page1.status_code == 200
    assert len(page1.json()["items"]) == 2
    assert page1.json()["total"] == 5

    assert page3.status_code == 200
    assert len(page3.json()["items"]) == 1
    assert page3.json()["total"] == 5

    assert page4.status_code == 200
    assert page4.json()["items"] == []
    assert page4.json()["total"] == 5


async def test_wrong_answers_excludes_other_users_entries(client, monkeypatch):
    headers_a, user_a = await _login(client, monkeypatch, provider_user_id="wa-owner-a")
    set_a = await _create_set(client, headers_a)
    material_a = await _insert_material(set_a)
    await _insert_wrong_answer(user_a, material_a)

    headers_b, user_b = await _login(client, monkeypatch, provider_user_id="wa-owner-b")
    set_b = await _create_set(client, headers_b)
    material_b = await _insert_material(set_b)
    await _insert_wrong_answer(user_b, material_b)

    resp = await client.get("/api/wrong-answers", headers=headers_b)

    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 1
    assert body["items"][0]["material_id"] == material_b


async def test_wrong_answers_item_includes_correct_answer_and_explanation(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)
    material_id = await _insert_material(set_id)
    await _insert_wrong_answer(user_id, material_id, correct_answer=3, explanation="이래서 정답")

    resp = await client.get("/api/wrong-answers", headers=headers)

    item = resp.json()["items"][0]
    assert item["correct_answer"] == 3
    assert item["explanation"] == "이래서 정답"


# ---- GET /api/sets/{set_id}/analysis ------------------------------------------------------------


async def test_analysis_returns_existing_row(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)
    await _insert_analysis(set_id, user_id, weak_topics=[{"topic": "순회", "accuracy": 40}], comment="분석 코멘트")

    resp = await client.get(f"/api/sets/{set_id}/analysis", headers=headers)

    assert resp.status_code == 200
    body = resp.json()
    assert body["set_id"] == set_id
    assert body["weak_topics"] == [{"topic": "순회", "accuracy": 40}]
    assert body["comment"] == "분석 코멘트"
    assert body["analyzed_at"] is not None
    # attempts를 하나도 안 쌓았으므로 정답률 3개 필드는 안전한 0이어야 한다.
    assert body["total_attempts"] == 0
    assert body["correct_count"] == 0
    assert body["overall_accuracy"] == 0.0


async def test_analysis_missing_returns_200_with_null_fields(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)

    resp = await client.get(f"/api/sets/{set_id}/analysis", headers=headers)

    assert resp.status_code == 200
    body = resp.json()
    assert body == {
        "set_id": set_id,
        "weak_topics": None,
        "comment": None,
        "analyzed_at": None,
        "total_attempts": 0,
        "correct_count": 0,
        "overall_accuracy": 0.0,
    }


async def test_analysis_includes_set_accuracy_from_attempts(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)
    material_id = await _insert_material(set_id)
    session_id = await _seed_dismissed_session(user_id, datetime.now(timezone.utc))
    await _seed_attempt(session_id, is_correct=True, material_id=material_id)
    await _seed_attempt(session_id, is_correct=True, material_id=material_id)
    await _seed_attempt(session_id, is_correct=False, material_id=material_id)

    resp = await client.get(f"/api/sets/{set_id}/analysis", headers=headers)

    assert resp.status_code == 200
    body = resp.json()
    assert body["total_attempts"] == 3
    assert body["correct_count"] == 2
    assert body["overall_accuracy"] == 66.7


async def test_analysis_accuracy_excludes_other_sets_attempts(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    set_a = await _create_set(client, headers, title="세트 A")
    set_b = await _create_set(client, headers, title="세트 B")
    material_a = await _insert_material(set_a)
    material_b = await _insert_material(set_b)
    session_id = await _seed_dismissed_session(user_id, datetime.now(timezone.utc))
    await _seed_attempt(session_id, is_correct=True, material_id=material_a)
    await _seed_attempt(session_id, is_correct=False, material_id=material_b)

    resp = await client.get(f"/api/sets/{set_a}/analysis", headers=headers)

    assert resp.status_code == 200
    body = resp.json()
    assert body["total_attempts"] == 1
    assert body["correct_count"] == 1
    assert body["overall_accuracy"] == 100.0


async def test_analysis_accuracy_present_even_without_weak_area_row(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)
    material_id = await _insert_material(set_id)
    session_id = await _seed_dismissed_session(user_id, datetime.now(timezone.utc))
    await _seed_attempt(session_id, is_correct=True, material_id=material_id)

    resp = await client.get(f"/api/sets/{set_id}/analysis", headers=headers)

    assert resp.status_code == 200
    body = resp.json()
    assert body["weak_topics"] is None
    assert body["comment"] is None
    assert body["total_attempts"] == 1
    assert body["correct_count"] == 1
    assert body["overall_accuracy"] == 100.0


async def test_analysis_other_users_set_returns_404(client, monkeypatch):
    headers_a, _ = await _login(client, monkeypatch, provider_user_id="analysis-owner-a")
    set_id = await _create_set(client, headers_a)

    headers_b, _ = await _login(client, monkeypatch, provider_user_id="analysis-owner-b")
    resp = await client.get(f"/api/sets/{set_id}/analysis", headers=headers_b)

    assert resp.status_code == 404
    assert resp.json()["error_code"] == "SET_NOT_FOUND"


# ---- GET /api/stats/summary ------------------------------------------------------------


async def test_summary_zero_data_returns_safe_zeros(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)

    resp = await client.get("/api/stats/summary", params={"tz": "UTC"}, headers=headers)

    assert resp.status_code == 200
    assert resp.json() == {
        "current_streak": 0,
        "total_study_days": 0,
        "total_attempts": 0,
        "correct_rate": 0.0,
        "total_sets": 0,
        "active_alarms": 0,
    }


async def test_summary_streak_continuous_over_three_days(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    now = datetime.now(timezone.utc)
    await _seed_dismissed_session(user_id, now)
    await _seed_dismissed_session(user_id, now - timedelta(days=1))
    await _seed_dismissed_session(user_id, now - timedelta(days=2))

    resp = await client.get("/api/stats/summary", params={"tz": "UTC"}, headers=headers)

    assert resp.status_code == 200
    body = resp.json()
    assert body["current_streak"] == 3
    assert body["total_study_days"] == 3


async def test_summary_streak_is_zero_when_broken(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    now = datetime.now(timezone.utc)
    await _seed_dismissed_session(user_id, now - timedelta(days=10))

    resp = await client.get("/api/stats/summary", params={"tz": "UTC"}, headers=headers)

    assert resp.status_code == 200
    body = resp.json()
    assert body["current_streak"] == 0
    assert body["total_study_days"] == 1


async def test_summary_streak_holds_through_yesterday_with_nothing_today(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    now = datetime.now(timezone.utc)
    await _seed_dismissed_session(user_id, now - timedelta(days=1))
    await _seed_dismissed_session(user_id, now - timedelta(days=2))
    # 오늘자 기록은 없음 — 그래도 어제까지 이어졌으니 끊긴 게 아니다

    resp = await client.get("/api/stats/summary", params={"tz": "UTC"}, headers=headers)

    assert resp.status_code == 200
    assert resp.json()["current_streak"] == 2


async def test_summary_timezone_changes_date_bucketing(client, monkeypatch):
    """동일한 두 dismissed_at이 tz에 따라 서로 다른/같은 날짜로 묶이는지 확인한다.

    '지금'에 의존하지 않도록 고정 시각을 쓴다: 2026-01-15T12:00Z와 그 13시간 뒤인
    2026-01-16T01:00Z는 UTC 기준 서로 다른 날짜지만, UTC+14(Etc/GMT-14) 기준으로는
    두 시각 모두 로컬 2026-01-16에 들어가 같은 날짜가 된다.
    """
    headers, user_id = await _login(client, monkeypatch)
    base = datetime(2026, 1, 15, 12, 0, 0, tzinfo=timezone.utc)
    await _seed_dismissed_session(user_id, base)
    await _seed_dismissed_session(user_id, base + timedelta(hours=13))

    utc_resp = await client.get("/api/stats/summary", params={"tz": "UTC"}, headers=headers)
    shifted_resp = await client.get("/api/stats/summary", params={"tz": "Etc/GMT-14"}, headers=headers)

    assert utc_resp.status_code == 200
    assert shifted_resp.status_code == 200
    assert utc_resp.json()["total_study_days"] == 2
    assert shifted_resp.json()["total_study_days"] == 1


async def test_summary_invalid_timezone_returns_400(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)

    resp = await client.get("/api/stats/summary", params={"tz": "Not/AZone"}, headers=headers)

    assert resp.status_code == 400
    assert resp.json()["error_code"] == "INVALID_TIMEZONE"


async def test_summary_correct_rate_calculation(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    session_id = await _seed_dismissed_session(user_id, datetime.now(timezone.utc))
    await _seed_attempt(session_id, is_correct=True)
    await _seed_attempt(session_id, is_correct=True)
    await _seed_attempt(session_id, is_correct=False)

    resp = await client.get("/api/stats/summary", params={"tz": "UTC"}, headers=headers)

    assert resp.status_code == 200
    body = resp.json()
    assert body["total_attempts"] == 3
    assert body["correct_rate"] == 66.7


async def test_summary_total_sets_and_active_alarms(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    await _create_set(client, headers, title="세트 1")
    await _create_set(client, headers, title="세트 2")
    await _create_alarm(client, headers, alarm_time="06:00", is_enabled=True)
    await _create_alarm(client, headers, alarm_time="07:00", is_enabled=True)
    await _create_alarm(client, headers, alarm_time="08:00", is_enabled=False)

    resp = await client.get("/api/stats/summary", params={"tz": "UTC"}, headers=headers)

    assert resp.status_code == 200
    body = resp.json()
    assert body["total_sets"] == 2
    assert body["active_alarms"] == 2


async def test_summary_excludes_other_users_data(client, monkeypatch):
    headers_a, user_a = await _login(client, monkeypatch, provider_user_id="summary-owner-a")
    await _create_set(client, headers_a)
    await _seed_dismissed_session(user_a, datetime.now(timezone.utc))

    headers_b, _ = await _login(client, monkeypatch, provider_user_id="summary-owner-b")
    resp = await client.get("/api/stats/summary", params={"tz": "UTC"}, headers=headers_b)

    assert resp.status_code == 200
    body = resp.json()
    assert body["total_sets"] == 0
    assert body["total_study_days"] == 0
    assert body["current_streak"] == 0
