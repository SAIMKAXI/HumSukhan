from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from uuid import UUID


# ===== Caption =====
class CaptionCreate(BaseModel):
    text: str
    speaker: str = "Speaker 1"
    language: str = "English"
    is_partial: bool = False
    is_own: bool = False


class CaptionResponse(BaseModel):
    id: str
    text: str
    speaker: str
    timestamp: datetime
    language: str
    is_partial: bool
    is_own: bool


# ===== Folder =====
class FolderCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)


class FolderResponse(BaseModel):
    id: UUID
    name: str
    session_count: int = 0
    created_at: datetime

    class Config:
        from_attributes = True


# ===== Session =====
class SessionCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=500)
    session_type: str = "meeting"  # meeting, lecture, class
    folder_id: Optional[UUID] = None
    caption_language: str = "English"
    retention_days: int = Field(default=7, ge=1, le=30)


class SessionUpdate(BaseModel):
    title: Optional[str] = None
    session_type: Optional[str] = None
    folder_id: Optional[UUID] = None
    status: Optional[str] = None


class SessionResponse(BaseModel):
    id: UUID
    title: str
    session_type: str
    status: str
    caption_language: str
    retention_days: int
    created_at: datetime
    expires_at: datetime
    completed_at: Optional[datetime]
    caption_count: int = 0
    folder_id: Optional[UUID]
    has_insight: bool = False
    days_remaining: int = 0

    class Config:
        from_attributes = True


class SessionDetailResponse(SessionResponse):
    captions: list[CaptionResponse] = []


# ===== Transcript =====
class TranscriptResponse(BaseModel):
    id: UUID
    session_id: UUID
    captions: list[CaptionResponse]
    plain_text: str
    word_count: int
    duration_seconds: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ===== Insight =====
class InsightResponse(BaseModel):
    id: UUID
    session_id: UUID
    summary: str
    vocabulary: list[str]
    themes: list[str]
    action_items: list[str]
    deadlines: list[str]
    mentioned_people: list[str]
    is_available: bool
    ai_model: Optional[str]
    generated_at: datetime

    class Config:
        from_attributes = True


# ===== Export =====
class ExportRequest(BaseModel):
    format: str = "txt"  # txt, pdf, clipboard
    include_summary: bool = True
    include_vocabulary: bool = True
    include_themes: bool = True
    include_action_items: bool = True
    include_deadlines: bool = True
    include_people: bool = True


class ExportResponse(BaseModel):
    id: UUID
    format: str
    content: str
    created_at: datetime


# ===== Stats =====
class UserStatsResponse(BaseModel):
    total_sessions: int
    total_folders: int
    total_captions: int
    active_sessions: int
    completed_sessions: int
    total_insights: int
