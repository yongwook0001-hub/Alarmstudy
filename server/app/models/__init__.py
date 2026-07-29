"""Alembic autogenerate가 Base.metadata를 완전히 채우도록 전 모델을 여기서 import한다."""

from app.db.base import Base
from app.models.alarm import Alarm
from app.models.alarm_session import AlarmSession
from app.models.generation_job import GenerationJob
from app.models.material_set import MaterialSet
from app.models.question import Question
from app.models.question_attempt import QuestionAttempt
from app.models.refresh_token import RefreshToken
from app.models.study_material import StudyMaterial
from app.models.user import User
from app.models.weak_area_analysis import WeakAreaAnalysis
from app.models.wrong_answer import WrongAnswer

__all__ = [
    "Base",
    "Alarm",
    "AlarmSession",
    "GenerationJob",
    "MaterialSet",
    "Question",
    "QuestionAttempt",
    "RefreshToken",
    "StudyMaterial",
    "User",
    "WeakAreaAnalysis",
    "WrongAnswer",
]
