import json
import logging
import asyncio
from typing import Dict, Set, Optional
from datetime import datetime, timezone
from uuid import uuid4, UUID
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.security import decode_token
from app.models.user import User
from app.models.professional import ProfessionalSession, Transcript

logger = logging.getLogger(__name__)
router = APIRouter(tags=["WebSocket"])


# ===== Connection Manager =====
class ConnectionManager:
    """Manages WebSocket connections for real-time caption sync."""

    def __init__(self):
        # session_id -> set of (websocket, user_id, username)
        self._rooms: Dict[str, Set[tuple]] = {}
        # websocket -> session_id
        self._connections: Dict[WebSocket, str] = {}

    async def connect(self, websocket: WebSocket, session_id: str, user_id: str, username: str):
        await websocket.accept()
        if session_id not in self._rooms:
            self._rooms[session_id] = set()
        self._rooms[session_id].add((websocket, user_id, username))
        self._connections[websocket] = session_id
        logger.info(f"User {username} connected to session {session_id}")

        # Notify others
        await self.broadcast_to_room(session_id, {
            "type": "user_joined",
            "user_id": user_id,
            "username": username,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "participants": self.get_participant_count(session_id),
        })

    def disconnect(self, websocket: WebSocket):
        session_id = self._connections.pop(websocket, None)
        if session_id and session_id in self._rooms:
            # Find and remove the connection
            to_remove = None
            for conn_tuple in self._rooms[session_id]:
                if conn_tuple[0] == websocket:
                    to_remove = conn_tuple
                    break
            if to_remove:
                self._rooms[session_id].discard(to_remove)
                username = to_remove[2]
                user_id = to_remove[1]
                logger.info(f"User {username} disconnected from session {session_id}")

                # Clean up empty rooms
                if not self._rooms[session_id]:
                    del self._rooms[session_id]
                return user_id, username
        return None, None

    async def broadcast_to_room(self, session_id: str, message: dict):
        if session_id not in self._rooms:
            return
        disconnected = []
        for websocket, _, _ in self._rooms[session_id]:
            try:
                await websocket.send_json(message)
            except Exception:
                disconnected.append(websocket)

        # Clean up disconnected
        for ws in disconnected:
            self.disconnect(ws)

    async def send_to_user(self, user_id: str, message: dict):
        for session_id, connections in self._rooms.items():
            for websocket, uid, _ in connections:
                if uid == user_id:
                    try:
                        await websocket.send_json(message)
                    except Exception:
                        pass

    def get_participant_count(self, session_id: str) -> int:
        return len(self._rooms.get(session_id, set()))

    def get_participants(self, session_id: str) -> list:
        if session_id not in self._rooms:
            return []
        return [{"user_id": uid, "username": uname} for _, uid, uname in self._rooms[session_id]]

    def is_user_in_session(self, user_id: str, session_id: str) -> bool:
        if session_id not in self._rooms:
            return False
        return any(uid == user_id for _, uid, _ in self._rooms[session_id])


# Global connection manager
manager = ConnectionManager()


# ===== WebSocket Endpoint =====
@router.websocket("/ws/session/{session_id}")
async def websocket_session(
    websocket: WebSocket,
    session_id: str,
    token: str = "",
):
    """
    WebSocket endpoint for real-time caption synchronization.

    Connect with: ws://host/api/v1/ws/session/{session_id}?token={jwt_token}

    Messages (client -> server):
    - {"type": "caption", "text": "...", "speaker": "...", "language": "..."}
    - {"type": "typing", "is_typing": true}
    - {"type": "ping"}

    Messages (server -> client):
    - {"type": "caption_broadcast", ...}
    - {"type": "user_joined", ...}
    - {"type": "user_left", ...}
    - {"type": "session_ended", ...}
    - {"type": "pong"}
    - {"type": "error", "message": "..."}
    """
    # Authenticate
    if not token:
        await websocket.close(code=4001, reason="Authentication required")
        return

    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        await websocket.close(code=4001, reason="Invalid token")
        return

    user_id = payload.get("sub")
    if not user_id:
        await websocket.close(code=4001, reason="Invalid token payload")
        return

    # Get user info
    from app.core.database import AsyncSessionLocal
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            await websocket.close(code=4004, reason="User not found")
            return

        # Verify session exists
        result = await db.execute(
            select(ProfessionalSession).where(ProfessionalSession.id == UUID(session_id))
        )
        session = result.scalar_one_or_none()
        if not session:
            await websocket.close(code=4004, reason="Session not found")
            return

    # Connect
    await manager.connect(websocket, session_id, user_id, user.username)

    try:
        while True:
            data = await websocket.receive_json()
            await handle_message(websocket, session_id, user_id, user.username, data)
    except WebSocketDisconnect:
        user_id_left, username_left = manager.disconnect(websocket)
        if user_id_left:
            await manager.broadcast_to_room(session_id, {
                "type": "user_left",
                "user_id": user_id_left,
                "username": username_left,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "participants": manager.get_participant_count(session_id),
            })
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        manager.disconnect(websocket)


async def handle_message(
    websocket: WebSocket,
    session_id: str,
    user_id: str,
    username: str,
    data: dict,
):
    """Handle incoming WebSocket messages."""
    msg_type = data.get("type")

    if msg_type == "caption":
        # Broadcast caption to all participants
        caption = {
            "type": "caption_broadcast",
            "id": str(uuid4()),
            "text": data.get("text", ""),
            "speaker": data.get("speaker", username),
            "language": data.get("language", "English"),
            "is_partial": data.get("is_partial", False),
            "user_id": user_id,
            "username": username,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        await manager.broadcast_to_room(session_id, caption)

        # Persist non-partial captions to database
        if not data.get("is_partial", False) and data.get("text", "").strip():
            await save_caption(session_id, caption)

    elif msg_type == "typing":
        # Broadcast typing indicator
        await manager.broadcast_to_room(session_id, {
            "type": "typing_indicator",
            "user_id": user_id,
            "username": username,
            "is_typing": data.get("is_typing", False),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })

    elif msg_type == "ping":
        await websocket.send_json({"type": "pong", "timestamp": datetime.now(timezone.utc).isoformat()})

    elif msg_type == "end_session":
        # End the session
        await manager.broadcast_to_room(session_id, {
            "type": "session_ended",
            "session_id": session_id,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })

    else:
        await websocket.send_json({
            "type": "error",
            "message": f"Unknown message type: {msg_type}",
        })


async def save_caption(session_id: str, caption: dict):
    """Persist a caption to the database."""
    try:
        from app.core.database import AsyncSessionLocal
        async with AsyncSessionLocal() as db:
            result = await db.execute(
                select(ProfessionalSession)
                .options(selectinload(ProfessionalSession.transcript))
                .where(ProfessionalSession.id == UUID(session_id))
            )
            session = result.scalar_one_or_none()
            if not session:
                return

            caption_data = {
                "id": caption["id"],
                "text": caption["text"],
                "speaker": caption["speaker"],
                "timestamp": caption["timestamp"],
                "language": caption.get("language", "English"),
                "is_partial": False,
                "is_own": False,
            }

            if not session.transcript:
                from app.models.professional import Transcript
                transcript = Transcript(
                    session_id=session.id,
                    captions=[caption_data],
                    plain_text=caption["text"],
                )
                db.add(transcript)
            else:
                captions = session.transcript.captions or []
                captions.append(caption_data)
                session.transcript.captions = captions
                session.transcript.plain_text = "\n".join([c["text"] for c in captions])

            await db.commit()
    except Exception as e:
        logger.error(f"Failed to save caption: {e}")


# ===== REST endpoints for WebSocket info =====
@router.get("/ws/session/{session_id}/participants")
async def get_participants(session_id: str):
    """Get current participants in a session."""
    participants = manager.get_participants(session_id)
    return {
        "session_id": session_id,
        "count": len(participants),
        "participants": participants,
    }
