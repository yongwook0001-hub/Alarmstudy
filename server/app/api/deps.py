from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.core.security import TokenExpiredError, TokenInvalidError, decode_access_token
from app.db.session import get_db
from app.models import MaterialSet, StudyMaterial

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


async def get_owned_material_set(
    set_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> MaterialSet:
    """경로의 set_id가 현재 유저 소유인지 확인한다.

    타인 소유·부존재는 구분하지 않고 동일하게 404 SET_NOT_FOUND로 은닉한다 (설계 확정).
    """
    material_set = await db.get(MaterialSet, set_id)
    if material_set is None or material_set.user_id != user_id:
        raise AppError(404, "SET_NOT_FOUND", "세트를 찾을 수 없습니다.")
    return material_set


async def get_owned_material(
    material_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> StudyMaterial:
    """경로의 material_id가 현재 유저 소유 세트에 속하는지 확인한다 (404로 은닉)."""
    material = await db.get(StudyMaterial, material_id)
    if material is None:
        raise AppError(404, "MATERIAL_NOT_FOUND", "자료를 찾을 수 없습니다.")

    owner_result = await db.execute(select(MaterialSet.user_id).where(MaterialSet.id == material.set_id))
    owner_id = owner_result.scalar_one_or_none()
    if owner_id != user_id:
        raise AppError(404, "MATERIAL_NOT_FOUND", "자료를 찾을 수 없습니다.")

    return material
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
