import logging
import uuid

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError
from starlette.concurrency import run_in_threadpool

from app.core.config import get_settings
from app.core.constants import PRESIGNED_URL_EXPIRES_SECONDS

logger = logging.getLogger(__name__)

_NOT_FOUND_ERROR_CODES = {"404", "NoSuchKey", "NotFound"}


def _client():
    """호출마다 새 클라이언트를 만든다 — moto의 mock_aws는 boto3.client() 생성 시점에
    패치가 적용되므로, 모듈 로드 시 캐싱해두면 테스트에서 목킹이 안 먹는다.

    addressing_style="virtual"을 명시한다 — 기본값(auto)으로 두면 일부 리전/버킷
    조합에서 presigned URL이 리전 정보 없는 글로벌 호스트(bucket.s3.amazonaws.com)로
    생성되어 실제 업로드 시 307 TemporaryRedirect가 발생한다 (스모크 테스트로 재현·확인됨).
    """
    settings = get_settings()
    config = Config(signature_version="s3v4", s3={"addressing_style": "virtual"})
    return boto3.client("s3", region_name=settings.aws_region, config=config)


def build_s3_key(user_id: int, set_id: int) -> str:
    return f"{user_id}/{set_id}/{uuid.uuid4()}.pdf"


def generate_presigned_put_url(s3_key: str) -> tuple[str, int]:
    """Presigned PUT URL 발급.

    ContentType을 서명 파라미터에 넣지 않는다 — 넣으면 앱이 업로드 시 정확히 같은
    Content-Type 헤더를 보내야만 서명이 맞는데, presigned-url 응답 스키마에 그걸
    알려줄 필드가 없어 앱과의 계약이 어긋난다. 순수 서명 생성이라 블로킹 I/O 없음.
    """
    settings = get_settings()
    expires_in = PRESIGNED_URL_EXPIRES_SECONDS
    url = _client().generate_presigned_url(
        "put_object",
        Params={"Bucket": settings.s3_bucket_name, "Key": s3_key},
        ExpiresIn=expires_in,
    )
    return url, expires_in


async def object_exists(s3_key: str) -> bool:
    settings = get_settings()

    def _head() -> bool:
        try:
            _client().head_object(Bucket=settings.s3_bucket_name, Key=s3_key)
            return True
        except ClientError as exc:
            error_code = exc.response.get("Error", {}).get("Code")
            if error_code in _NOT_FOUND_ERROR_CODES:
                return False
            raise

    return await run_in_threadpool(_head)


async def download_object(s3_key: str) -> bytes:
    settings = get_settings()

    def _get() -> bytes:
        response = _client().get_object(Bucket=settings.s3_bucket_name, Key=s3_key)
        return response["Body"].read()

    return await run_in_threadpool(_get)


async def delete_object(s3_key: str) -> None:
    await delete_objects([s3_key])


async def delete_objects(s3_keys: list[str]) -> None:
    """S3 객체 일괄 삭제. 실패해도 예외를 올리지 않고 로그만 남긴다.

    설계: 세트/자료/회원탈퇴 삭제 시 S3 실패가 DB 삭제를 막으면 안 된다.
    """
    if not s3_keys:
        return

    settings = get_settings()

    def _delete() -> None:
        client = _client()
        # S3 DeleteObjects는 요청당 최대 1000개
        for i in range(0, len(s3_keys), 1000):
            batch = s3_keys[i : i + 1000]
            client.delete_objects(
                Bucket=settings.s3_bucket_name,
                Delete={"Objects": [{"Key": key} for key in batch]},
            )

    try:
        await run_in_threadpool(_delete)
    except Exception:
        logger.exception("S3 객체 삭제 실패 (%d개) — 호출부는 계속 진행", len(s3_keys))
