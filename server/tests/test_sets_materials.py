from datetime import time as dt_time
from urllib.parse import urlparse

import boto3
import pytest
from moto import mock_aws

from app.core.config import get_settings
from app.core.constants import (
    MAX_FILE_SIZE_BYTES,
    MAX_FILES_PER_SET,
    MAX_TOTAL_SIZE_PER_SET_BYTES,
)
from app.db.session import AsyncSessionLocal
from app.models import Alarm, MaterialSet, Question, StudyMaterial
from app.services.oauth import OAuthUserInfo


# ---- helpers ------------------------------------------------------------


class _FakeVerifier:
    def __init__(self, info: OAuthUserInfo) -> None:
        self._info = info

    async def verify(self, oauth_token: str) -> OAuthUserInfo:
        return self._info


async def _login(client, monkeypatch, provider_user_id: str = "materials-test-uid"):
    info = OAuthUserInfo(provider_user_id=provider_user_id, nickname="테스터", email="tester@example.com")
    monkeypatch.setattr("app.api.auth.get_oauth_verifier", lambda provider: _FakeVerifier(info))
    resp = await client.post("/api/auth/login", json={"provider": "google", "oauth_token": "irrelevant"})
    body = resp.json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


async def _create_set(client, headers, title: str = "테스트 세트") -> int:
    resp = await client.post("/api/sets", json={"title": title}, headers=headers)
    return resp.json()["id"]


async def _insert_material(set_id: int, **overrides) -> int:
    defaults = dict(
        set_id=set_id,
        is_main=False,
        file_name="existing.pdf",
        s3_key=f"seed/{set_id}/{overrides.get('file_name', 'existing.pdf')}-{overrides.get('_i', 0)}.pdf",
        file_size_bytes=1024,
        upload_status="ready",
    )
    defaults.update({k: v for k, v in overrides.items() if k != "_i"})
    async with AsyncSessionLocal() as db:
        material = StudyMaterial(**defaults)
        db.add(material)
        await db.commit()
        await db.refresh(material)
        return material.id


def _build_minimal_pdf() -> bytes:
    """오프셋을 직접 계산해서 만드는 최소 1페이지 유효 PDF (pdfplumber가 열 수 있어야 함)."""
    header = b"%PDF-1.4\n"
    objects = [
        b"1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n",
        b"2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n",
        b"3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Resources<<>>>>endobj\n",
    ]
    offsets = []
    body = b""
    for obj in objects:
        offsets.append(len(header) + len(body))
        body += obj

    xref_offset = len(header) + len(body)
    xref = b"xref\n0 %d\n0000000000 65535 f \n" % (len(objects) + 1)
    for off in offsets:
        xref += b"%010d 00000 n \n" % off

    trailer = b"trailer<</Size %d/Root 1 0 R>>\nstartxref\n%d\n%%%%EOF" % (len(objects) + 1, xref_offset)
    return header + body + xref + trailer


class _FakeSummaryGenerator:
    def __init__(self, summary: str = "AI가 생성한 요약입니다.") -> None:
        self._summary = summary

    async def generate(self, text: str) -> str:
        return self._summary


@pytest.fixture(autouse=True)
def _s3_bucket():
    with mock_aws():
        settings = get_settings()
        create_kwargs = {"Bucket": settings.s3_bucket_name}
        # us-east-1 외 리전은 CreateBucketConfiguration 없이 보내면 실제 S3(및 moto)가
        # IllegalLocationConstraintException을 낸다 — region-specific 엔드포인트 계약.
        if settings.aws_region != "us-east-1":
            create_kwargs["CreateBucketConfiguration"] = {"LocationConstraint": settings.aws_region}
        boto3.client("s3", region_name=settings.aws_region).create_bucket(**create_kwargs)
        yield


def _s3_client():
    settings = get_settings()
    return boto3.client("s3", region_name=settings.aws_region), settings.s3_bucket_name


# ---- sets ------------------------------------------------------------


async def test_create_and_list_sets(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)

    create_resp = await client.post("/api/sets", json={"title": "운영체제"}, headers=headers)
    assert create_resp.status_code == 201
    assert create_resp.json()["title"] == "운영체제"

    list_resp = await client.get("/api/sets", headers=headers)
    assert list_resp.status_code == 200
    items = list_resp.json()
    assert len(items) == 1
    assert items[0]["title"] == "운영체제"
    assert items[0]["material_count"] == 0


async def test_get_set_detail_hides_other_users_set_as_404(client, monkeypatch):
    headers_a, _ = await _login(client, monkeypatch, provider_user_id="user-a")
    set_id = await _create_set(client, headers_a)

    headers_b, _ = await _login(client, monkeypatch, provider_user_id="user-b")
    resp = await client.get(f"/api/sets/{set_id}", headers=headers_b)

    assert resp.status_code == 404
    assert resp.json()["error_code"] == "SET_NOT_FOUND"


async def test_get_set_detail_excludes_extracted_text_and_s3_key(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)
    await _insert_material(set_id, extracted_text="비밀 원문", summary="공개 요약")

    resp = await client.get(f"/api/sets/{set_id}", headers=headers)

    assert resp.status_code == 200
    material = resp.json()["materials"][0]
    assert material["summary"] == "공개 요약"
    assert "extracted_text" not in material
    assert "s3_key" not in material


async def test_patch_set_title(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers, title="old")

    resp = await client.patch(f"/api/sets/{set_id}", json={"title": "new"}, headers=headers)

    assert resp.status_code == 200
    assert resp.json()["title"] == "new"


async def test_delete_set_deletes_s3_objects_and_demotes_alarms(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)

    s3_client, bucket = _s3_client()
    s3_key = f"{user_id}/{set_id}/seed.pdf"
    s3_client.put_object(Bucket=bucket, Key=s3_key, Body=b"%PDF-1.4 fake")
    await _insert_material(set_id, s3_key=s3_key)

    async with AsyncSessionLocal() as db:
        alarm = Alarm(user_id=user_id, set_id=set_id, alarm_time=dt_time(7, 0))
        db.add(alarm)
        await db.commit()
        await db.refresh(alarm)
        alarm_id = alarm.id

    resp = await client.delete(f"/api/sets/{set_id}", headers=headers)
    assert resp.status_code == 200

    with pytest.raises(Exception):
        s3_client.head_object(Bucket=bucket, Key=s3_key)

    async with AsyncSessionLocal() as db:
        assert await db.get(MaterialSet, set_id) is None
        refreshed_alarm = await db.get(Alarm, alarm_id)
        assert refreshed_alarm is not None
        assert refreshed_alarm.set_id is None


# ---- materials: presigned-url ------------------------------------------------------------


async def test_presigned_url_success_defaults_is_main_false(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)

    resp = await client.post(
        f"/api/sets/{set_id}/materials/presigned-url",
        json={"file_name": "lecture.pdf", "file_size_bytes": 1000},
        headers=headers,
    )

    assert resp.status_code == 201
    body = resp.json()
    assert body["upload_url"]
    assert body["s3_key"].endswith(".pdf")
    assert body["expires_in"] > 0

    async with AsyncSessionLocal() as db:
        material = await db.get(StudyMaterial, body["material_id"])
        assert material.upload_status == "pending"
        assert material.is_main is False


async def test_presigned_url_host_includes_region(client, monkeypatch):
    """generate_presigned_put_url이 만든 URL의 호스트에 리전이 포함되는지 확인한다.

    addressing_style이 기본값(auto)이면 일부 리전/버킷 조합에서 리전 정보 없는
    글로벌 호스트(bucket.s3.amazonaws.com)가 나와, 실제 업로드 시 S3가 307
    TemporaryRedirect를 반환한다. moto는 URL 문자열이 아니라 요청을 가로채므로
    이 문제를 재현하지 못해 URL 자체를 직접 검증한다.
    """
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)

    resp = await client.post(
        f"/api/sets/{set_id}/materials/presigned-url",
        json={"file_name": "lecture.pdf", "file_size_bytes": 1000},
        headers=headers,
    )

    assert resp.status_code == 201
    upload_url = resp.json()["upload_url"]
    host = urlparse(upload_url).netloc
    region = get_settings().aws_region
    assert region in host, f"presigned URL host missing region, got: {host}"


async def test_presigned_url_invalid_file_type(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)

    resp = await client.post(
        f"/api/sets/{set_id}/materials/presigned-url",
        json={"file_name": "notes.txt", "file_size_bytes": 1000},
        headers=headers,
    )

    assert resp.status_code == 400
    assert resp.json()["error_code"] == "INVALID_FILE_TYPE"


async def test_presigned_url_file_too_large(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)

    resp = await client.post(
        f"/api/sets/{set_id}/materials/presigned-url",
        json={"file_name": "big.pdf", "file_size_bytes": MAX_FILE_SIZE_BYTES + 1},
        headers=headers,
    )

    assert resp.status_code == 400
    assert resp.json()["error_code"] == "FILE_TOO_LARGE"


async def test_presigned_url_set_limit_exceeded_by_count(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)
    for i in range(MAX_FILES_PER_SET):
        await _insert_material(set_id, file_name=f"f{i}.pdf", s3_key=f"seed/{set_id}/f{i}.pdf", _i=i)

    resp = await client.post(
        f"/api/sets/{set_id}/materials/presigned-url",
        json={"file_name": "one-too-many.pdf", "file_size_bytes": 1000},
        headers=headers,
    )

    assert resp.status_code == 409
    assert resp.json()["error_code"] == "SET_LIMIT_EXCEEDED"


async def test_presigned_url_set_limit_exceeded_by_total_size(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)

    # 개당 한도는 안 넘기면서, 3개 합계가 총량 한도의 4분의 3 정도가 되게 채운다
    per_file = min(MAX_TOTAL_SIZE_PER_SET_BYTES // 4, MAX_FILE_SIZE_BYTES - 1024)
    for i in range(3):
        await _insert_material(
            set_id, file_name=f"big{i}.pdf", s3_key=f"seed/{set_id}/big{i}.pdf", file_size_bytes=per_file, _i=i
        )
    remaining = MAX_TOTAL_SIZE_PER_SET_BYTES - (per_file * 3)
    assert remaining > 0  # 이 테스트가 총량 조건만 건드리는지 확인하는 전제

    resp = await client.post(
        f"/api/sets/{set_id}/materials/presigned-url",
        json={"file_name": "final.pdf", "file_size_bytes": remaining + 1024},
        headers=headers,
    )

    assert resp.status_code == 409
    assert resp.json()["error_code"] == "SET_LIMIT_EXCEEDED"


async def test_presigned_url_is_main_switch_demotes_previous_main(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)

    first = await client.post(
        f"/api/sets/{set_id}/materials/presigned-url",
        json={"file_name": "a.pdf", "file_size_bytes": 1000, "is_main": True},
        headers=headers,
    )
    second = await client.post(
        f"/api/sets/{set_id}/materials/presigned-url",
        json={"file_name": "b.pdf", "file_size_bytes": 1000, "is_main": True},
        headers=headers,
    )
    assert first.status_code == 201
    assert second.status_code == 201

    async with AsyncSessionLocal() as db:
        first_material = await db.get(StudyMaterial, first.json()["material_id"])
        second_material = await db.get(StudyMaterial, second.json()["material_id"])
        assert first_material.is_main is False
        assert second_material.is_main is True


async def test_material_not_found_for_other_user(client, monkeypatch):
    headers_a, _ = await _login(client, monkeypatch, provider_user_id="mat-user-a")
    set_id = await _create_set(client, headers_a)
    material_id = await _insert_material(set_id)

    headers_b, _ = await _login(client, monkeypatch, provider_user_id="mat-user-b")
    resp = await client.delete(f"/api/materials/{material_id}", headers=headers_b)

    assert resp.status_code == 404
    assert resp.json()["error_code"] == "MATERIAL_NOT_FOUND"


# ---- materials: upload-complete + parsing ------------------------------------------------------------


async def test_upload_complete_success_then_background_parsing_marks_ready(client, monkeypatch):
    monkeypatch.setattr(
        "app.services.parsing._default_summary_generator",
        lambda: _FakeSummaryGenerator("한 줄 요약"),
    )

    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)

    presign_resp = await client.post(
        f"/api/sets/{set_id}/materials/presigned-url",
        json={"file_name": "real.pdf", "file_size_bytes": 1000},
        headers=headers,
    )
    material_id = presign_resp.json()["material_id"]
    s3_key = presign_resp.json()["s3_key"]

    s3_client, bucket = _s3_client()
    s3_client.put_object(Bucket=bucket, Key=s3_key, Body=_build_minimal_pdf())

    resp = await client.post(f"/api/materials/{material_id}/upload-complete", headers=headers)

    assert resp.status_code == 200
    assert resp.json()["upload_status"] == "uploaded"  # 응답은 파싱 전 즉시 값

    # ASGITransport는 BackgroundTasks까지 끝난 뒤에 응답을 돌려주므로 이 시점엔 이미 파싱이 끝나 있다.
    async with AsyncSessionLocal() as db:
        material = await db.get(StudyMaterial, material_id)
        assert material.upload_status == "ready"
        assert material.page_count == 1
        assert material.summary == "한 줄 요약"
        assert material.extracted_text is not None


async def test_upload_complete_missing_s3_object_returns_409(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)

    presign_resp = await client.post(
        f"/api/sets/{set_id}/materials/presigned-url",
        json={"file_name": "never-uploaded.pdf", "file_size_bytes": 1000},
        headers=headers,
    )
    material_id = presign_resp.json()["material_id"]

    resp = await client.post(f"/api/materials/{material_id}/upload-complete", headers=headers)

    assert resp.status_code == 409
    assert resp.json()["error_code"] == "UPLOAD_NOT_FOUND_IN_S3"

    async with AsyncSessionLocal() as db:
        material = await db.get(StudyMaterial, material_id)
        assert material.upload_status == "pending"


async def test_upload_complete_invalid_pdf_marks_parse_failed(client, monkeypatch):
    headers, _ = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)

    presign_resp = await client.post(
        f"/api/sets/{set_id}/materials/presigned-url",
        json={"file_name": "corrupt.pdf", "file_size_bytes": 1000},
        headers=headers,
    )
    material_id = presign_resp.json()["material_id"]
    s3_key = presign_resp.json()["s3_key"]

    s3_client, bucket = _s3_client()
    s3_client.put_object(Bucket=bucket, Key=s3_key, Body=b"this is not a pdf at all")

    resp = await client.post(f"/api/materials/{material_id}/upload-complete", headers=headers)
    assert resp.status_code == 200

    async with AsyncSessionLocal() as db:
        material = await db.get(StudyMaterial, material_id)
        assert material.upload_status == "parse_failed"


async def test_delete_material_cascades_questions_and_deletes_s3_object(client, monkeypatch):
    headers, user_id = await _login(client, monkeypatch)
    set_id = await _create_set(client, headers)

    s3_client, bucket = _s3_client()
    s3_key = f"{user_id}/{set_id}/to-delete.pdf"
    s3_client.put_object(Bucket=bucket, Key=s3_key, Body=b"%PDF-1.4 fake")
    material_id = await _insert_material(set_id, s3_key=s3_key, upload_status="ready")

    async with AsyncSessionLocal() as db:
        question = Question(
            material_id=material_id,
            content="1+1=?",
            choices=["1", "2", "3", "4"],
            correct_answer=1,
            topic="산수",
        )
        db.add(question)
        await db.commit()
        await db.refresh(question)
        question_id = question.id

    resp = await client.delete(f"/api/materials/{material_id}", headers=headers)
    assert resp.status_code == 200

    with pytest.raises(Exception):
        s3_client.head_object(Bucket=bucket, Key=s3_key)

    async with AsyncSessionLocal() as db:
        assert await db.get(StudyMaterial, material_id) is None
        assert await db.get(Question, question_id) is None
