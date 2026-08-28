import uuid
from datetime import datetime, timedelta, timezone
from sqlalchemy import Column, String, DateTime, Integer, Float, Text, ForeignKey, Enum as SAEnum, Boolean
from sqlalchemy.dialects.postgresql import UUID, JSONB, ARRAY
from sqlalchemy.orm import relationship
from app.core.database import Base
import enum


class SessionType(str, enum.Enum):
    meeting = "meeting"
    lecture = "lecture"
    class_ = "class"


class SessionStatus(str, enum.Enum):
    in_progress = "in_progress"
    completed = "completed"
    archived = "archived"


class Folder(Base):
    __tablename__ = "folders"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(255), nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    user = relationship("User", back_populates="folders")
    sessions = relationship("ProfessionalSession", back_populates="folder", cascade="all, delete-orphan")


class ProfessionalSession(Base):
    __tablename__ = "professional_sessions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    folder_id = Column(UUID(as_uuid=True), ForeignKey("folders.id", ondelete="SET NULL"), nullable=True)
    title = Column(String(500), nullable=False)
    session_type = Column(SAEnum(SessionType), nullable=False, default=SessionType.meeting)
    status = Column(SAEnum(SessionStatus), nullable=False, default=SessionStatus.in_progress)
    caption_language = Column(String(50), default="English")
    retention_days = Column(Integer, default=7)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    expires_at = Column(DateTime(timezone=True), nullable=False)
    completed_at = Column(DateTime(timezone=True), nullable=True)

    user = relationship("User", back_populates="sessions")
    folder = relationship("Folder", back_populates="sessions")
    transcript = relationship("Transcript", back_populates="session", uselist=False, cascade="all, delete-orphan")
    insight = relationship("ProfessionalInsight", back_populates="session", uselist=False, cascade="all, delete-orphan")

    @property
    def is_expired(self) -> bool:
        return datetime.now(timezone.utc) > self.expires_at

    @property
    def days_remaining(self) -> int:
        delta = self.expires_at - datetime.now(timezone.utc)
        return max(0, delta.days)


class Transcript(Base):
    __tablename__ = "transcripts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(UUID(as_uuid=True), ForeignKey("professional_sessions.id", ondelete="CASCADE"), nullable=False, unique=True)
    captions = Column(JSONB, default=list)  # [{id, text, speaker, timestamp, language, is_partial, is_own}]
    plain_text = Column(Text, default="")
    word_count = Column(Integer, default=0)
    duration_seconds = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    session = relationship("ProfessionalSession", back_populates="transcript")


class ProfessionalInsight(Base):
    __tablename__ = "professional_insights"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(UUID(as_uuid=True), ForeignKey("professional_sessions.id", ondelete="CASCADE"), nullable=False, unique=True)
    summary = Column(Text, default="")
    vocabulary = Column(ARRAY(Text), default=list)
    themes = Column(ARRAY(Text), default=list)
    action_items = Column(ARRAY(Text), default=list)
    deadlines = Column(ARRAY(Text), default=list)
    mentioned_people = Column(ARRAY(Text), default=list)
    is_available = Column(Boolean, default=False)
    ai_model = Column(String(100), nullable=True)
    generated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    session = relationship("ProfessionalSession", back_populates="insight")
