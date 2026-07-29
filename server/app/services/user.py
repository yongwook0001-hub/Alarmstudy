import logging

logger = logging.getLogger(__name__)


async def delete_user_s3_objects(s3_keys: list[str]) -> None:
    """회원탈퇴 시 유저 소유 S3 객체를 지우는 훅.

    S3 연동 전까지는 no-op(로그만). 다음 단계에서 boto3로 채운다 —
    실제 구현도 실패 시 예외를 던지지 말고 로그만 남겨야 한다
    (설계: S3 삭제 실패해도 DB 하드 삭제는 진행).
    """
    if not s3_keys:
        return
    logger.info("S3 미연동 — 삭제 스킵(no-op). 대상 s3_key %d개: %s", len(s3_keys), s3_keys)
