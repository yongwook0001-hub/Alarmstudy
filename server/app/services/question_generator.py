import json
import logging
import os
from collections.abc import Sequence
from dataclasses import dataclass
from typing import Protocol

from google import genai
from google.genai import types

from app.core.config import get_settings
from app.core.constants import GENERATION_BATCH_SIZE, MAIN_MATERIAL_WEIGHT, TOKEN_LIMIT_PER_SET
from app.models import MaterialSet, StudyMaterial

logger = logging.getLogger(__name__)

_GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash-lite")


class QuestionGenerationError(Exception):
    """Gemini 호출 실패 또는 응답 JSON 파싱 실패."""


@dataclass(frozen=True)
class RawGenerationResponse:
    text: str
    tokens_used: int


class QuestionGenerationClient(Protocol):
    async def generate(self, prompt: str) -> RawGenerationResponse: ...


class GeminiQuestionGenerationClient:
    """google-genai로 문제를 생성한다. app/services/parsing.py의 SummaryGenerator와
    동일한 패턴 — Protocol을 만족하는 얇은 래퍼라 테스트에서 통째로 교체(mock) 가능하다."""

    def __init__(self, api_key: str, model_name: str = _GEMINI_MODEL) -> None:
        self._api_key = api_key
        self._model_name = model_name

    async def generate(self, prompt: str) -> RawGenerationResponse:
        client = genai.Client(api_key=self._api_key)
        try:
            response = await client.aio.models.generate_content(
                model=self._model_name,
                contents=prompt,
                config=types.GenerateContentConfig(response_mime_type="application/json"),
            )
        except Exception as exc:
            raise QuestionGenerationError(str(exc)) from exc

        tokens_used = response.usage_metadata.total_token_count if response.usage_metadata else 0
        return RawGenerationResponse(text=response.text or "", tokens_used=tokens_used or 0)


def _default_generation_client() -> QuestionGenerationClient:
    return GeminiQuestionGenerationClient(api_key=get_settings().gemini_api_key)


@dataclass(frozen=True)
class GeneratedQuestion:
    content: str
    choices: list[str]
    correct_answer: int
    explanation: str | None
    topic: str


# parsing.py의 GeminiSummaryGenerator와 동일한 상한 — 발췌 길이를 확정 상수 산정 기준
# (입력 ≈8K 토큰)에 맞게 눌러둔다. 확정 상수가 아니라 구현상 안전장치라 constants.py에 두지 않는다.
_MAX_EXCERPT_CHARS = 20_000

_PROMPT_TEMPLATE = """다음은 학습 자료에서 추출한 텍스트다. 이 내용만 근거로 4지선다 객관식 문제를 정확히 {count}개 만들어라.

학습 자료:
{excerpt}

아래 JSON 스키마를 따르는 객체 {count}개로 이루어진 배열만 반환해라. 배열 외 다른 텍스트는 절대 포함하지 마라.
[
  {{
    "content": "문제 지문",
    "choices": ["보기1", "보기2", "보기3", "보기4"],
    "correct_answer": 0,
    "explanation": "정답 해설",
    "topic": "문제가 다루는 세부 주제"
  }}
]
- choices는 정확히 4개
- correct_answer는 choices의 정답 보기 인덱스(0~3)
- topic은 반드시 채워라 (통계 집계에 쓰이는 필수 항목)
"""


def _build_prompt(extracted_text: str, count: int) -> str:
    excerpt = extracted_text[:_MAX_EXCERPT_CHARS]
    return _PROMPT_TEMPLATE.format(count=count, excerpt=excerpt)


def _parse_questions(raw_text: str) -> list[GeneratedQuestion]:
    try:
        data = json.loads(raw_text)
        if not isinstance(data, list):
            raise ValueError(f"최상위 응답은 배열이어야 합니다 (받은 타입: {type(data).__name__})")

        questions: list[GeneratedQuestion] = []
        for item in data:
            choices = list(item["choices"])
            if len(choices) != 4:
                raise ValueError(f"choices는 4개여야 합니다 (받은 개수: {len(choices)})")

            correct_answer = int(item["correct_answer"])
            if not 0 <= correct_answer <= 3:
                raise ValueError(f"correct_answer는 0~3이어야 합니다 (받은 값: {correct_answer})")

            content = item["content"]
            if not isinstance(content, str) or not content.strip():
                raise ValueError("content는 필수입니다")

            topic = item.get("topic")
            if not isinstance(topic, str) or not topic.strip():
                raise ValueError("topic은 필수입니다")

            questions.append(
                GeneratedQuestion(
                    content=content,
                    choices=choices,
                    correct_answer=correct_answer,
                    explanation=item.get("explanation"),
                    topic=topic.strip(),
                )
            )
    except (json.JSONDecodeError, KeyError, TypeError, ValueError) as exc:
        raise QuestionGenerationError(f"AI 응답 파싱 실패: {exc}") from exc

    if not questions:
        raise QuestionGenerationError("AI 응답 파싱 실패: 생성된 문제가 없습니다")

    return questions


def _split_evenly(material_ids: Sequence[int], total: int) -> dict[int, int]:
    if not material_ids or total <= 0:
        return {}
    base, extra = divmod(total, len(material_ids))
    return {material_id: base + (1 if i < extra else 0) for i, material_id in enumerate(material_ids)}


def allocate_counts(materials: Sequence[StudyMaterial], target_count: int) -> dict[int, int]:
    """세트 내 자료별 생성 개수 배분.

    메인 자료에 MAIN_MATERIAL_WEIGHT, 나머지는 서브끼리 균등(반올림). 메인이 없거나
    서브가 없으면(메인만 있으면 자연히 100%) 대상 전체를 균등 분배한다.
    """
    if target_count <= 0 or not materials:
        return {}

    main = next((m for m in materials if m.is_main), None)
    subs = [m for m in materials if not m.is_main]

    if main is None or not subs:
        return _split_evenly([m.id for m in materials], target_count)

    main_count = min(round(target_count * MAIN_MATERIAL_WEIGHT), target_count)
    allocation = {main.id: main_count}
    allocation.update(_split_evenly([m.id for m in subs], target_count - main_count))
    return allocation


async def generate_questions_for_set(
    material_set: MaterialSet,
    materials: Sequence[StudyMaterial],
    target_count: int,
    client: QuestionGenerationClient | None = None,
) -> dict[int, list[GeneratedQuestion]]:
    """세트 전체 생성 루프: 가중치 배분 → 자료별 배치 호출(GENERATION_BATCH_SIZE 이하) 반복.

    material_set.tokens_used를 직접 갱신한다 (커밋은 호출부 책임). TOKEN_LIMIT_PER_SET에
    도달하면 남은 배분을 포기하고 그때까지 생성된 분량만 반환한다 — 예외가 아니라 정상 중단이다.
    """
    ready_materials = [m for m in materials if m.extracted_text]
    if target_count <= 0 or not ready_materials:
        return {}

    generator = client or _default_generation_client()
    allocations = allocate_counts(ready_materials, target_count)

    results: dict[int, list[GeneratedQuestion]] = {}

    for material in ready_materials:
        remaining = allocations.get(material.id, 0)
        if remaining <= 0:
            continue

        material_questions: list[GeneratedQuestion] = []
        while remaining > 0:
            if material_set.tokens_used >= TOKEN_LIMIT_PER_SET:
                logger.info("세트 토큰 한도 도달— 생성 중단 (set_id=%s)", material_set.id)
                if material_questions:
                    results[material.id] = material_questions
                return results

            batch_size = min(remaining, GENERATION_BATCH_SIZE)
            response = await generator.generate(_build_prompt(material.extracted_text, batch_size))
            material_set.tokens_used += response.tokens_used

            generated = _parse_questions(response.text)
            material_questions.extend(generated)
            remaining -= len(generated)

        results[material.id] = material_questions

    return results
