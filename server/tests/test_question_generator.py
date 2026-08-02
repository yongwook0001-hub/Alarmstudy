import json

import pytest

from app.core.constants import GENERATION_BATCH_SIZE, TOKEN_LIMIT_PER_SET
from app.models import MaterialSet, StudyMaterial
from app.services.question_generator import (
    QuestionGenerationError,
    RawGenerationResponse,
    allocate_counts,
    generate_questions_for_set,
)


# ---- helpers ------------------------------------------------------------


def _material(id: int, is_main: bool, extracted_text: str | None = "본문 텍스트") -> StudyMaterial:
    return StudyMaterial(
        id=id,
        set_id=1,
        is_main=is_main,
        file_name=f"m{id}.pdf",
        s3_key=f"k{id}",
        file_size_bytes=1,
        upload_status="ready" if extracted_text else "uploaded",
        extracted_text=extracted_text,
    )


def _questions_json(n: int) -> str:
    return json.dumps(
        [
            {
                "content": f"문제 {i}",
                "choices": ["a", "b", "c", "d"],
                "correct_answer": i % 4,
                "explanation": "설명",
                "topic": "토픽",
            }
            for i in range(n)
        ]
    )


class _FakeGenerationClient:
    """generate() 호출 순서대로 (text, tokens_used) 계획을 하나씩 소비하는 목 클라이언트."""

    def __init__(self, plan: list[tuple[str, int]]) -> None:
        self._plan = list(plan)
        self.calls = 0

    async def generate(self, prompt: str) -> RawGenerationResponse:
        text, tokens = self._plan[self.calls]
        self.calls += 1
        return RawGenerationResponse(text=text, tokens_used=tokens)


# ---- allocate_counts (가중치 배분) ------------------------------------------------------------


def test_allocate_counts_main_gets_configured_weight():
    main = _material(1, is_main=True)
    sub1 = _material(2, is_main=False)
    sub2 = _material(3, is_main=False)

    allocation = allocate_counts([main, sub1, sub2], 20)

    assert allocation[main.id] == 14  # 20 * MAIN_MATERIAL_WEIGHT(0.7) = 14, 정확히 70%
    assert allocation[sub1.id] + allocation[sub2.id] == 6
    assert abs(allocation[sub1.id] - allocation[sub2.id]) <= 1
    assert sum(allocation.values()) == 20


def test_allocate_counts_no_subs_gives_main_full_target():
    main = _material(1, is_main=True)

    allocation = allocate_counts([main], 20)

    assert allocation == {1: 20}


def test_allocate_counts_no_main_splits_all_materials_evenly():
    a = _material(1, is_main=False)
    b = _material(2, is_main=False)

    allocation = allocate_counts([a, b], 10)

    assert allocation == {1: 5, 2: 5}


def test_allocate_counts_zero_target_returns_empty():
    main = _material(1, is_main=True)

    assert allocate_counts([main], 0) == {}


# ---- generate_questions_for_set (배치·토큰누적·한도) ------------------------------------------------------------


async def test_repeats_calls_when_target_exceeds_batch_size():
    material_set = MaterialSet(id=1, user_id=1, title="세트", tokens_used=0)
    material = _material(1, is_main=True)
    target = GENERATION_BATCH_SIZE * 2

    client = _FakeGenerationClient(
        [
            (_questions_json(GENERATION_BATCH_SIZE), 1000),
            (_questions_json(GENERATION_BATCH_SIZE), 1000),
        ]
    )

    result = await generate_questions_for_set(material_set, [material], target, client=client)

    assert client.calls == 2
    assert len(result[material.id]) == target
    assert material_set.tokens_used == 2000


async def test_single_call_when_target_within_batch_size():
    material_set = MaterialSet(id=1, user_id=1, title="세트", tokens_used=0)
    material = _material(1, is_main=True)
    target = min(3, GENERATION_BATCH_SIZE)

    client = _FakeGenerationClient([(_questions_json(target), 300)])

    result = await generate_questions_for_set(material_set, [material], target, client=client)

    assert client.calls == 1
    assert len(result[material.id]) == target


async def test_stops_when_token_limit_already_reached():
    material_set = MaterialSet(id=1, user_id=1, title="세트", tokens_used=TOKEN_LIMIT_PER_SET)
    material = _material(1, is_main=True)

    client = _FakeGenerationClient([(_questions_json(GENERATION_BATCH_SIZE), 100)])

    result = await generate_questions_for_set(material_set, [material], GENERATION_BATCH_SIZE, client=client)

    assert client.calls == 0
    assert result == {}
    assert material_set.tokens_used == TOKEN_LIMIT_PER_SET


async def test_stops_mid_run_once_token_limit_is_crossed():
    material_set = MaterialSet(id=1, user_id=1, title="세트", tokens_used=TOKEN_LIMIT_PER_SET - 50)
    material = _material(1, is_main=True)
    target = GENERATION_BATCH_SIZE * 3  # 한도만 없으면 3회 호출이 필요한 양

    client = _FakeGenerationClient(
        [
            (_questions_json(GENERATION_BATCH_SIZE), 100),  # 이 한 번으로 한도를 넘긴다
            (_questions_json(GENERATION_BATCH_SIZE), 100),
            (_questions_json(GENERATION_BATCH_SIZE), 100),
        ]
    )

    result = await generate_questions_for_set(material_set, [material], target, client=client)

    assert client.calls == 1  # 한도 초과 직후 더 호출하지 않는다
    assert len(result[material.id]) == GENERATION_BATCH_SIZE
    assert material_set.tokens_used == TOKEN_LIMIT_PER_SET + 50


async def test_skips_materials_without_extracted_text():
    material_set = MaterialSet(id=1, user_id=1, title="세트", tokens_used=0)
    ready = _material(1, is_main=True, extracted_text="본문")
    not_ready = _material(2, is_main=False, extracted_text=None)

    client = _FakeGenerationClient([(_questions_json(5), 100)])

    result = await generate_questions_for_set(material_set, [ready, not_ready], 5, client=client)

    assert client.calls == 1
    assert set(result.keys()) == {ready.id}


async def test_malformed_json_raises_question_generation_error():
    material_set = MaterialSet(id=1, user_id=1, title="세트", tokens_used=0)
    material = _material(1, is_main=True)

    client = _FakeGenerationClient([("이건 JSON이 아님", 50)])

    with pytest.raises(QuestionGenerationError):
        await generate_questions_for_set(material_set, [material], 3, client=client)


async def test_missing_required_field_raises_question_generation_error():
    material_set = MaterialSet(id=1, user_id=1, title="세트", tokens_used=0)
    material = _material(1, is_main=True)

    bad_payload = json.dumps([{"content": "문제", "choices": ["a", "b", "c", "d"], "correct_answer": 0}])
    client = _FakeGenerationClient([(bad_payload, 50)])  # topic 누락

    with pytest.raises(QuestionGenerationError):
        await generate_questions_for_set(material_set, [material], 3, client=client)
