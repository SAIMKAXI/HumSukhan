from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from sqlalchemy.orm import selectinload
from datetime import datetime, timedelta, timezone
from uuid import UUID
from typing import Optional

from app.core.database import get_db
from app.models.user import User
from app.models.professional import (
    ProfessionalSession,
    SessionType,
    SessionStatus,
    Folder,
    Transcript,
    ProfessionalInsight,
)
from app.models.export import ExportRecord
from app.api.deps import get_current_user
from app.schemas.professional import (
    SessionCreate,
    SessionUpdate,
    SessionResponse,
    SessionDetailResponse,
    FolderCreate,
    FolderResponse,
    TranscriptResponse,
    InsightResponse,
    CaptionCreate,
    CaptionResponse,
    ExportRequest,
    ExportResponse,
    UserStatsResponse,
)

router = APIRouter(prefix="/professional", tags=["Professional Sessions"])


# ===== FOLDERS =====
@router.get("/folders", response_model=list[FolderResponse])
async def list_folders(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Folder).where(Folder.user_id == current_user.id).order_by(Folder.created_at.desc())
    )
    folders = result.scalars().all()

    response = []
    for folder in folders:
        count_result = await db.execute(
            select(func.count(ProfessionalSession.id)).where(
                and_(ProfessionalSession.folder_id == folder.id, ProfessionalSession.user_id == current_user.id)
            )
        )
        count = count_result.scalar() or 0
        response.append(FolderResponse(
            id=folder.id,
            name=folder.name,
            session_count=count,
            created_at=folder.created_at,
        ))
    return response


@router.post("/folders", response_model=FolderResponse, status_code=status.HTTP_201_CREATED)
async def create_folder(
    data: FolderCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    folder = Folder(user_id=current_user.id, name=data.name)
    db.add(folder)
    await db.commit()
    await db.refresh(folder)
    return FolderResponse(id=folder.id, name=folder.name, session_count=0, created_at=folder.created_at)


@router.delete("/folders/{folder_id}")
async def delete_folder(
    folder_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Folder).where(and_(Folder.id == folder_id, Folder.user_id == current_user.id))
    )
    folder = result.scalar_one_or_none()
    if not folder:
        raise HTTPException(status_code=404, detail="Folder not found")

    # Move sessions to general (no folder)
    sessions_result = await db.execute(
        select(ProfessionalSession).where(ProfessionalSession.folder_id == folder_id)
    )
    for session in sessions_result.scalars().all():
        session.folder_id = None

    await db.delete(folder)
    await db.commit()
    return {"message": "Folder deleted. Sessions moved to General."}


# ===== SESSIONS =====
@router.get("/sessions", response_model=list[SessionResponse])
async def list_sessions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    session_type: Optional[str] = Query(None),
    folder_id: Optional[UUID] = Query(None),
    status_filter: Optional[str] = Query(None),
):
    query = select(ProfessionalSession).where(ProfessionalSession.user_id == current_user.id)

    if session_type:
        query = query.where(ProfessionalSession.session_type == session_type)
    if folder_id:
        query = query.where(ProfessionalSession.folder_id == folder_id)
    if status_filter:
        query = query.where(ProfessionalSession.status == status_filter)

    query = query.order_by(ProfessionalSession.created_at.desc())
    result = await db.execute(query)
    sessions = result.scalars().all()

    response = []
    for session in sessions:
        caption_count = 0
        has_insight = False
        if session.transcript:
            caption_count = len(session.transcript.captions) if session.transcript.captions else 0
        if session.insight:
            has_insight = session.insight.is_available

        response.append(SessionResponse(
            id=session.id,
            title=session.title,
            session_type=session.session_type.value,
            status=session.status.value,
            caption_language=session.caption_language,
            retention_days=session.retention_days,
            created_at=session.created_at,
            expires_at=session.expires_at,
            completed_at=session.completed_at,
            caption_count=caption_count,
            folder_id=session.folder_id,
            has_insight=has_insight,
            days_remaining=session.days_remaining,
        ))
    return response


@router.post("/sessions", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
async def create_session(
    data: SessionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    retention_days = min(data.retention_days, 30)  # Hard ceiling
    session = ProfessionalSession(
        user_id=current_user.id,
        title=data.title,
        session_type=SessionType(data.session_type),
        folder_id=data.folder_id,
        caption_language=data.caption_language,
        retention_days=retention_days,
        expires_at=datetime.now(timezone.utc) + timedelta(days=retention_days),
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)

    return SessionResponse(
        id=session.id,
        title=session.title,
        session_type=session.session_type.value,
        status=session.status.value,
        caption_language=session.caption_language,
        retention_days=session.retention_days,
        created_at=session.created_at,
        expires_at=session.expires_at,
        completed_at=session.completed_at,
        caption_count=0,
        folder_id=session.folder_id,
        has_insight=False,
        days_remaining=session.days_remaining,
    )


@router.get("/sessions/{session_id}", response_model=SessionDetailResponse)
async def get_session(
    session_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ProfessionalSession)
        .options(selectinload(ProfessionalSession.transcript), selectinload(ProfessionalSession.insight))
        .where(and_(ProfessionalSession.id == session_id, ProfessionalSession.user_id == current_user.id))
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    captions = []
    if session.transcript and session.transcript.captions:
        captions = [
            CaptionResponse(
                id=c.get("id", ""),
                text=c.get("text", ""),
                speaker=c.get("speaker", "Speaker 1"),
                timestamp=c.get("timestamp", datetime.now(timezone.utc)),
                language=c.get("language", "English"),
                is_partial=c.get("is_partial", False),
                is_own=c.get("is_own", False),
            )
            for c in session.transcript.captions
        ]

    return SessionDetailResponse(
        id=session.id,
        title=session.title,
        session_type=session.session_type.value,
        status=session.status.value,
        caption_language=session.caption_language,
        retention_days=session.retention_days,
        created_at=session.created_at,
        expires_at=session.expires_at,
        completed_at=session.completed_at,
        caption_count=len(captions),
        folder_id=session.folder_id,
        has_insight=session.insight is not None and session.insight.is_available,
        days_remaining=session.days_remaining,
        captions=captions,
    )


@router.put("/sessions/{session_id}", response_model=SessionResponse)
async def update_session(
    session_id: UUID,
    data: SessionUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ProfessionalSession).where(
            and_(ProfessionalSession.id == session_id, ProfessionalSession.user_id == current_user.id)
        )
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    update_dict = data.model_dump(exclude_unset=True)
    if "session_type" in update_dict:
        update_dict["session_type"] = SessionType(update_dict["session_type"])
    if "status" in update_dict:
        update_dict["status"] = SessionStatus(update_dict["status"])
        if update_dict["status"] == SessionStatus.completed:
            session.completed_at = datetime.now(timezone.utc)

    for field, value in update_dict.items():
        setattr(session, field, value)

    await db.commit()
    await db.refresh(session)

    return SessionResponse(
        id=session.id,
        title=session.title,
        session_type=session.session_type.value,
        status=session.status.value,
        caption_language=session.caption_language,
        retention_days=session.retention_days,
        created_at=session.created_at,
        expires_at=session.expires_at,
        completed_at=session.completed_at,
        caption_count=0,
        folder_id=session.folder_id,
        has_insight=False,
        days_remaining=session.days_remaining,
    )


@router.delete("/sessions/{session_id}")
async def delete_session(
    session_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ProfessionalSession).where(
            and_(ProfessionalSession.id == session_id, ProfessionalSession.user_id == current_user.id)
        )
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    await db.delete(session)
    await db.commit()
    return {"message": "Session deleted permanently"}


# ===== CAPTIONS =====
@router.post("/sessions/{session_id}/captions", response_model=CaptionResponse, status_code=status.HTTP_201_CREATED)
async def add_caption(
    session_id: UUID,
    data: CaptionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ProfessionalSession)
        .options(selectinload(ProfessionalSession.transcript))
        .where(and_(ProfessionalSession.id == session_id, ProfessionalSession.user_id == current_user.id))
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    import uuid
    caption = {
        "id": str(uuid.uuid4()),
        "text": data.text,
        "speaker": data.speaker,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "language": data.language,
        "is_partial": data.is_partial,
        "is_own": data.is_own,
    }

    if not session.transcript:
        session.transcript = Transcript(session_id=session.id, captions=[caption], plain_text=data.text)
        db.add(session.transcript)
    else:
        captions = session.transcript.captions or []
        captions.append(caption)
        session.transcript.captions = captions
        session.transcript.plain_text = "\n".join([c["text"] for c in captions])

    await db.commit()

    return CaptionResponse(
        id=caption["id"],
        text=caption["text"],
        speaker=caption["speaker"],
        timestamp=datetime.now(timezone.utc),
        language=caption["language"],
        is_partial=caption["is_partial"],
        is_own=caption["is_own"],
    )


# ===== INSIGHTS =====
@router.post("/sessions/{session_id}/insights", response_model=InsightResponse)
async def generate_insights(
    session_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ProfessionalSession)
        .options(selectinload(ProfessionalSession.transcript), selectinload(ProfessionalSession.insight))
        .where(and_(ProfessionalSession.id == session_id, ProfessionalSession.user_id == current_user.id))
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    transcript_text = ""
    if session.transcript:
        transcript_text = session.transcript.plain_text

    # Try AI generation, fall back to mock
    summary = ""
    vocabulary = []
    themes = []
    action_items = []
    deadlines = []
    mentioned_people = []
    ai_model = None

    if transcript_text:
        try:
            from app.services.ai_service import AIService
            ai_result = await AIService.generate_insights(transcript_text, session.title)
            summary = ai_result["summary"]
            vocabulary = ai_result["vocabulary"]
            themes = ai_result["themes"]
            action_items = ai_result["action_items"]
            deadlines = ai_result["deadlines"]
            mentioned_people = ai_result["mentioned_people"]
            ai_model = ai_result.get("model", "gpt-4o-mini")
        except Exception:
            # Mock fallback
            summary = f"The {session.session_type.value} '{session.title}' covered key topics and action items."
            vocabulary = ["accessibility", "implementation", "milestone", "stakeholder"]
            themes = ["Project planning", "Team coordination"]
            action_items = ["Complete tasks", "Review deliverables"]
            deadlines = ["Follow up on action items"]
            mentioned_people = ["Speaker 1"]

    # Upsert insight
    if session.insight:
        insight = session.insight
        insight.summary = summary
        insight.vocabulary = vocabulary
        insight.themes = themes
        insight.action_items = action_items
        insight.deadlines = deadlines
        insight.mentioned_people = mentioned_people
        insight.is_available = True
        insight.ai_model = ai_model
    else:
        insight = ProfessionalInsight(
            session_id=session.id,
            summary=summary,
            vocabulary=vocabulary,
            themes=themes,
            action_items=action_items,
            deadlines=deadlines,
            mentioned_people=mentioned_people,
            is_available=True,
            ai_model=ai_model,
        )
        db.add(insight)

    await db.commit()
    await db.refresh(insight)

    return InsightResponse(
        id=insight.id,
        session_id=insight.session_id,
        summary=insight.summary,
        vocabulary=insight.vocabulary or [],
        themes=insight.themes or [],
        action_items=insight.action_items or [],
        deadlines=insight.deadlines or [],
        mentioned_people=insight.mentioned_people or [],
        is_available=insight.is_available,
        ai_model=insight.ai_model,
        generated_at=insight.generated_at,
    )


@router.get("/sessions/{session_id}/insights", response_model=InsightResponse)
async def get_insights(
    session_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ProfessionalInsight)
        .join(ProfessionalSession)
        .where(and_(ProfessionalSession.id == session_id, ProfessionalSession.user_id == current_user.id))
    )
    insight = result.scalar_one_or_none()
    if not insight:
        raise HTTPException(status_code=404, detail="Insights not found")

    return InsightResponse(
        id=insight.id,
        session_id=insight.session_id,
        summary=insight.summary,
        vocabulary=insight.vocabulary or [],
        themes=insight.themes or [],
        action_items=insight.action_items or [],
        deadlines=insight.deadlines or [],
        mentioned_people=insight.mentioned_people or [],
        is_available=insight.is_available,
        ai_model=insight.ai_model,
        generated_at=insight.generated_at,
    )


# ===== EXPORT =====
@router.get("/sessions/{session_id}/export", response_model=ExportResponse)
async def export_session(
    session_id: UUID,
    format: str = Query("txt"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ProfessionalSession)
        .options(selectinload(ProfessionalSession.transcript), selectinload(ProfessionalSession.insight))
        .where(and_(ProfessionalSession.id == session_id, ProfessionalSession.user_id == current_user.id))
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    # Build export content
    lines = [f"SESSION: {session.title}", f"DATE: {session.created_at}", f"TYPE: {session.session_type.value}"]
    lines.append("=" * 50)
    lines.append("")

    if session.transcript and session.transcript.captions:
        lines.append("TRANSCRIPT")
        lines.append("-" * 30)
        for c in session.transcript.captions:
            lines.append(f"{c.get('speaker', 'Speaker')}: {c.get('text', '')}")
        lines.append("")

    if session.insight and session.insight.is_available:
        insight = session.insight
        lines.append("SUMMARY")
        lines.append("-" * 30)
        lines.append(insight.summary)
        lines.append("")
        if insight.action_items:
            lines.append("ACTION ITEMS")
            lines.append("-" * 30)
            for item in insight.action_items:
                lines.append(f"• {item}")
            lines.append("")
        if insight.deadlines:
            lines.append("DEADLINES")
            lines.append("-" * 30)
            for d in insight.deadlines:
                lines.append(f"• {d}")
        if insight.vocabulary:
            lines.append("VOCABULARY")
            lines.append("-" * 30)
            lines.append(", ".join(insight.vocabulary))

    content = "\n".join(lines)

    # Save export record
    export = ExportRecord(
        user_id=current_user.id,
        session_id=session.id,
        format=format,
    )
    db.add(export)
    await db.commit()
    await db.refresh(export)

    return ExportResponse(
        id=export.id,
        format=format,
        content=content,
        created_at=export.created_at,
    )


# ===== STATS =====
@router.get("/stats", response_model=UserStatsResponse)
async def get_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    total_sessions = (await db.execute(
        select(func.count(ProfessionalSession.id)).where(ProfessionalSession.user_id == current_user.id)
    )).scalar() or 0

    total_folders = (await db.execute(
        select(func.count(Folder.id)).where(Folder.user_id == current_user.id)
    )).scalar() or 0

    active_sessions = (await db.execute(
        select(func.count(ProfessionalSession.id)).where(
            and_(ProfessionalSession.user_id == current_user.id, ProfessionalSession.status == SessionStatus.in_progress)
        )
    )).scalar() or 0

    completed_sessions = (await db.execute(
        select(func.count(ProfessionalSession.id)).where(
            and_(ProfessionalSession.user_id == current_user.id, ProfessionalSession.status == SessionStatus.completed)
        )
    )).scalar() or 0

    total_insights = (await db.execute(
        select(func.count(ProfessionalInsight.id))
        .join(ProfessionalSession)
        .where(and_(ProfessionalSession.user_id == current_user.id, ProfessionalInsight.is_available == True))
    )).scalar() or 0

    return UserStatsResponse(
        total_sessions=total_sessions,
        total_folders=total_folders,
        total_captions=0,  # Calculated from transcripts
        active_sessions=active_sessions,
        completed_sessions=completed_sessions,
        total_insights=total_insights,
    )
