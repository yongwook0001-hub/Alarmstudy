from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.errors import AppError
from app.core.security import TokenExpiredError, TokenInvalidError, decode_access_token

_bearer_scheme = HTTPBearer(auto_error=False)


async def get_current_user_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
) -> int:
    """Bearer 인증 의존성. 로컬 서명검증만 수행한다 — DB조회·외부호출 없음 (설계 확정).

    유저 프로필이 필요한 라우터는 이 함수가 돌려준 user_id로 각자 필요한
    조회를 직접 수행한다 (예: GET /users/me).
    """
    if credentials is None:
        raise AppError(401, "ACCESS_TOKEN_INVALID", "Authorization 헤더가 필요합니다.")

    try:
        return decode_access_token(credentials.credentials)
    except TokenExpiredError as exc:
        raise AppError(401, "ACCESS_TOKEN_EXPIRED", "액세스 토큰이 만료되었습니다.") from exc
    except TokenInvalidError as exc:
        raise AppError(401, "ACCESS_TOKEN_INVALID", "유효하지 않은 액세스 토큰입니다.") from exc
