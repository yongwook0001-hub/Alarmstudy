from app.services import s3


async def delete_user_s3_objects(s3_keys: list[str]) -> None:
    """회원탈퇴 시 유저 소유 S3 객체를 일괄 삭제한다.

    s3.delete_objects가 실패를 내부에서 삼키고 로그만 남기므로 (설계: S3 삭제
    실패해도 DB 하드 삭제는 진행) 여기서는 별도 예외처리 없이 그대로 위임한다.
    """
    await s3.delete_objects(s3_keys)
