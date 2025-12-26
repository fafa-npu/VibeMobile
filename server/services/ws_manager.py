"""WebSocket connection management."""

import asyncio
import json
from datetime import datetime
from typing import Optional
from fastapi import WebSocket
import logging

from ..config import settings
from ..models import SessionOutput, WSMessage

logger = logging.getLogger(__name__)


class ConnectionManager:
    """Manages WebSocket connections."""

    def __init__(self):
        self.active_connections: dict[str, WebSocket] = {}  # connection_id -> websocket
        self.subscriptions: dict[str, set[str]] = {}  # session_id -> set of connection_ids
        self.desktop_connections: set[str] = set()  # Desktop app connections
        self._heartbeat_interval = settings.ws_heartbeat_interval

    async def connect(self, websocket: WebSocket, connection_id: str) -> None:
        """Accept a new WebSocket connection."""
        await websocket.accept()
        self.active_connections[connection_id] = websocket
        logger.info(f"WebSocket connected: {connection_id}")

    def disconnect(self, connection_id: str) -> None:
        """Remove a WebSocket connection."""
        if connection_id in self.active_connections:
            del self.active_connections[connection_id]

        # Remove from desktop connections
        self.desktop_connections.discard(connection_id)

        # Remove from all subscriptions
        for session_id in list(self.subscriptions.keys()):
            self.subscriptions[session_id].discard(connection_id)
            if not self.subscriptions[session_id]:
                del self.subscriptions[session_id]

        logger.info(f"WebSocket disconnected: {connection_id}")

    def register_desktop(self, connection_id: str) -> None:
        """Register a connection as Desktop app."""
        self.desktop_connections.add(connection_id)
        logger.info(f"Desktop connection registered: {connection_id}")

    def unregister_desktop(self, connection_id: str) -> None:
        """Unregister a Desktop connection."""
        self.desktop_connections.discard(connection_id)

    def subscribe(self, connection_id: str, session_ids: list[str]) -> None:
        """Subscribe a connection to session updates."""
        for session_id in session_ids:
            if session_id not in self.subscriptions:
                self.subscriptions[session_id] = set()
            self.subscriptions[session_id].add(connection_id)
        logger.info(f"Connection {connection_id} subscribed to: {session_ids}")

    def unsubscribe(self, connection_id: str, session_ids: Optional[list[str]] = None) -> None:
        """Unsubscribe a connection from session updates."""
        if session_ids is None:
            # Unsubscribe from all
            for session_id in list(self.subscriptions.keys()):
                self.subscriptions[session_id].discard(connection_id)
        else:
            for session_id in session_ids:
                if session_id in self.subscriptions:
                    self.subscriptions[session_id].discard(connection_id)

    async def send_personal(self, connection_id: str, message: dict) -> bool:
        """Send a message to a specific connection."""
        websocket = self.active_connections.get(connection_id)
        if websocket:
            try:
                await websocket.send_json(message)
                return True
            except Exception as e:
                logger.error(f"Error sending to {connection_id}: {e}")
                self.disconnect(connection_id)
        return False

    async def broadcast_to_session(self, session_id: str, message: dict) -> None:
        """Broadcast a message to all connections subscribed to a session."""
        connection_ids = self.subscriptions.get(session_id, set()).copy()
        for connection_id in connection_ids:
            await self.send_personal(connection_id, message)

    async def broadcast_output(self, output: SessionOutput) -> None:
        """Broadcast session output to subscribers."""
        message = {
            "type": "session.output",
            "data": {
                "sessionId": output.session_id,
                "content": output.content,
                "timestamp": output.timestamp.isoformat(),
                "isDiff": output.is_diff,
            },
        }
        await self.broadcast_to_session(output.session_id, message)

    async def broadcast_status(self, session_id: str, status: str) -> None:
        """Broadcast session status change."""
        message = {
            "type": "session.status",
            "data": {
                "sessionId": session_id,
                "status": status,
                "timestamp": datetime.now().isoformat(),
            },
        }
        await self.broadcast_to_session(session_id, message)

    async def broadcast_all(self, message: dict) -> None:
        """Broadcast a message to all connections."""
        for connection_id in list(self.active_connections.keys()):
            await self.send_personal(connection_id, message)

    async def broadcast_to_desktop(self, message: dict) -> None:
        """Broadcast a message to all Desktop app connections."""
        for connection_id in list(self.desktop_connections):
            await self.send_personal(connection_id, message)

    async def handle_message(self, connection_id: str, data: dict) -> None:
        """Handle an incoming WebSocket message."""
        msg_type = data.get("type")

        if msg_type == "subscribe":
            session_ids = data.get("sessionIds", [])
            self.subscribe(connection_id, session_ids)
            await self.send_personal(
                connection_id,
                {"type": "subscribed", "data": {"sessionIds": session_ids}},
            )

        elif msg_type == "unsubscribe":
            session_ids = data.get("sessionIds")
            self.unsubscribe(connection_id, session_ids)
            await self.send_personal(
                connection_id,
                {"type": "unsubscribed", "data": {"sessionIds": session_ids}},
            )

        elif msg_type == "ping":
            await self.send_personal(
                connection_id,
                {"type": "pong", "data": {"timestamp": datetime.now().isoformat()}},
            )

        elif msg_type == "register_desktop":
            # Register as Desktop app connection
            self.register_desktop(connection_id)
            await self.send_personal(
                connection_id,
                {"type": "desktop_registered", "data": {"connectionId": connection_id}},
            )

        else:
            logger.warning(f"Unknown message type: {msg_type}")


# Singleton instance
ws_manager = ConnectionManager()
