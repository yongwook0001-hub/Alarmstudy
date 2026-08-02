from fastapi import APIRouter, BackgroundTasks, Depends
from pydantic import BaseModel
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user_id, get_owned_material, get_owned_material_set
from app.core.constants import MAX_FILE_SIZE_BYTES, MAX_FILES_PER_SET, MAX_TOTAL_SIZE_PER_SET_BYTES
from app.core.errors import AppError
from app.db.session import get_db
from app.models import MaterialSet, StudyMaterial
from app.services import s3
from app.services.parsing import parse_material

router = APIRouter()


# ---- schemas ---------------------------------------------------------------


class PresignedUrlRequest(BaseModel):
    file_name: str
    file_size_bytes: int
    is_main: bool = False


class PresignedUrlResponse(BaseModel):
    material_id: int
    upload_url: str
    s3_key: str
    expires_in: int


class UploadCompleteResponse(BaseModel):
    id: int
    upload_status: str


# ---- routes ------------------------------------------------------------


@router.post(
    "/sets/{set_id}/materials/presigned-url",
    response_model=PresignedUrlResponse,
    status_code=201,
)
async def create_presigned_url(
    body: PresignedUrlRequest,
    material_set: MaterialSet = Depends(get_owned_material_set),
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> PresignedUrlResponse:
    if not body.file_name.lower().endswith(".pdf"):
        raise AppError(400, "INVALID_FILE_TYPE", "PDF 파일만 업로드할 수 있습니다.")

    if body.file_size_bytes > MAX_FILE_SIZE_BYTES:
        raise AppError(400, "FILE_TOO_LARGE", f"파일 크기는 {MAX_FILE_SIZE_BYTES}바이트를 넘을 수 없습니다.")

    current_count, current_total_size = (
        await db.execute(
            select(
                func.count(StudyMaterial.id),
                func.coalesce(func.sum(StudyMaterial.file_size_bytes), 0),
            ).where(StudyMaterial.set_id == material_set.id)
        )
    ).one()

    if current_count + 1 > MAX_FILES_PER_SET:
        raise AppError(409, "SET_LIMIT_EXCEEDED", f"세트당 파일은 최대 {MAX_FILES_PER_SET}개까지 가능합니다.")

    if current_total_size + body.file_size_bytes > MAX_TOTAL_SIZE_PER_SET_BYTES:
        raise AppError(
            409, "SET_LIMIT_EXCEEDED", f"세트 총 용량은 {MAX_TOTAL_SIZE_PER_SET_BYTES}바이트를 넘을 수 없습니다."
        )

    if body.is_main:
        # 기존 메인 해제 — 아래 INSERT와 같은 트랜잭션(같은 db 세션, 아직 commit 전)에서 처리된다.
        await db.execute(
            update(StudyMaterial)
            .where(StudyMaterial.set_id == material_set.id, StudyMaterial.is_main.is_(True))
            .values(is_main=False)
        )

    s3_key = s3.build_s3_key(user_id=user_id, set_id=material_set.id)

    material = StudyMaterial(
        set_id=material_set.id,
        is_main=body.is_main,
        file_name=body.file_name,
        s3_key=s3_key,
        file_size_bytes=body.file_size_bytes,
        upload_status="pending",
    )
    db.add(material)
    await db.commit()
    await db.refresh(material)

    upload_url, expires_in = s3.generate_presigned_put_url(s3_key)

    return PresignedUrlResponse(
        material_id=material.id,
        upload_url=upload_url,
        s3_key=s3_key,
        expires_in=expires_in,
    )


@router.post("/materials/{material_id}/upload-complete", response_model=UploadCompleteResponse)
async def upload_complete(
    background_tasks: BackgroundTasks,
    material: StudyMaterial = Depends(get_owned_material),
    db: AsyncSession = Depends(get_db),
) -> UploadCompleteResponse:
    if not await s3.object_exists(material.s3_key):
        raise AppError(409, "UPLOAD_NOT_FOUND_IN_S3", "S3에서 업로드된 파일을 찾을 수 없습니다.")

    material.upload_status = "uploaded"
    await db.commit()

    background_tasks.add_task(parse_material, material.id)

    return UploadCompleteResponse(id=material.id, upload_status=material.upload_status)


@router.delete("/materials/{material_id}")
async def delete_material(
    material: StudyMaterial = Depends(get_owned_material),
    db: AsyncSession = Depends(get_db),
) -> dict:
    await s3.delete_object(material.s3_key)  # 실패해도 로그만 남기고 진행

    # CASCADE: questions/wrong_answers 연쇄삭제. 메인 삭제 시 세트는 메인 부재
    # 상태로 남는다 (다음 업로드에서 지정 — 여기서 다른 자료를 승격하지 않는다).
    await db.delete(material)
    await db.commit()
    return {}
