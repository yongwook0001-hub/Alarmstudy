from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user_id, get_owned_material_set
from app.db.session import get_db
from app.models import MaterialSet, StudyMaterial
from app.services import s3

router = APIRouter()


# ---- schemas ---------------------------------------------------------------


class SetCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=100)


class SetPatchRequest(BaseModel):
    title: str = Field(min_length=1, max_length=100)


class SetOut(BaseModel):
    id: int
    title: str
    created_at: datetime
    updated_at: datetime


class SetListItem(BaseModel):
    id: int
    title: str
    material_count: int
    created_at: datetime
    updated_at: datetime


class MaterialNested(BaseModel):
    """세트 상세에 중첩되는 자료 표현 — extracted_text·s3_key는 의도적으로 제외."""

    id: int
    is_main: bool
    file_name: str
    file_size_bytes: int
    upload_status: str
    page_count: int | None
    summary: str | None
    created_at: datetime


class SetDetailResponse(BaseModel):
    id: int
    title: str
    created_at: datetime
    updated_at: datetime
    materials: list[MaterialNested]


def _to_set_out(material_set: MaterialSet) -> SetOut:
    return SetOut(
        id=material_set.id,
        title=material_set.title,
        created_at=material_set.created_at,
        updated_at=material_set.updated_at,
    )


# ---- routes ------------------------------------------------------------


@router.post("/sets", response_model=SetOut, status_code=201)
async def create_set(
    body: SetCreateRequest,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> SetOut:
    material_set = MaterialSet(user_id=user_id, title=body.title)
    db.add(material_set)
    await db.commit()
    await db.refresh(material_set)
    return _to_set_out(material_set)


@router.get("/sets", response_model=list[SetListItem])
async def list_sets(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> list[SetListItem]:
    result = await db.execute(
        select(MaterialSet, func.count(StudyMaterial.id))
        .outerjoin(StudyMaterial, StudyMaterial.set_id == MaterialSet.id)
        .where(MaterialSet.user_id == user_id)
        .group_by(MaterialSet.id)
        .order_by(MaterialSet.created_at.desc())
    )
    return [
        SetListItem(
            id=material_set.id,
            title=material_set.title,
            material_count=material_count,
            created_at=material_set.created_at,
            updated_at=material_set.updated_at,
        )
        for material_set, material_count in result.all()
    ]


@router.get("/sets/{set_id}", response_model=SetDetailResponse)
async def get_set_detail(
    material_set: MaterialSet = Depends(get_owned_material_set),
    db: AsyncSession = Depends(get_db),
) -> SetDetailResponse:
    materials_result = await db.execute(
        select(StudyMaterial)
        .where(StudyMaterial.set_id == material_set.id)
        .order_by(StudyMaterial.created_at.asc())
    )
    materials = materials_result.scalars().all()

    return SetDetailResponse(
        id=material_set.id,
        title=material_set.title,
        created_at=material_set.created_at,
        updated_at=material_set.updated_at,
        materials=[
            MaterialNested(
                id=m.id,
                is_main=m.is_main,
                file_name=m.file_name,
                file_size_bytes=m.file_size_bytes,
                upload_status=m.upload_status,
                page_count=m.page_count,
                summary=m.summary,
                created_at=m.created_at,
            )
            for m in materials
        ],
    )


@router.patch("/sets/{set_id}", response_model=SetOut)
async def update_set(
    body: SetPatchRequest,
    material_set: MaterialSet = Depends(get_owned_material_set),
    db: AsyncSession = Depends(get_db),
) -> SetOut:
    material_set.title = body.title
    await db.commit()
    await db.refresh(material_set)
    return _to_set_out(material_set)


@router.delete("/sets/{set_id}")
async def delete_set(
    material_set: MaterialSet = Depends(get_owned_material_set),
    db: AsyncSession = Depends(get_db),
) -> dict:
    keys_result = await db.execute(select(StudyMaterial.s3_key).where(StudyMaterial.set_id == material_set.id))
    s3_keys = list(keys_result.scalars().all())

    await s3.delete_objects(s3_keys)  # 실패해도 로그만 남기고 진행 (서비스 내부에서 처리)

    # CASCADE: study_materials/questions/wrong_answers/generation_jobs/weak_area_analyses 연쇄삭제.
    # 연결 알람은 FK SET NULL로 자동 일반 알람 강등.
    await db.delete(material_set)
    await db.commit()
    return {}
