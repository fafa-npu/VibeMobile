"""Notification API routes for Claude Code hooks.

This module provides a REST API endpoint for receiving notifications from
Claude Code hooks (e.g., Stop hook) and broadcasting them to connected clients.

Architecture:
    Claude Code Hook -> REST API -> NotificationService -> WebSocket broadcast

Extension points:
    - Add new notification types by extending NotificationType enum
    - Customize notification handling by modifying NotificationService
    - Add notification persistence by implementing a storage backend
"""

from datetime import datetime
from enum import Enum
from typing import Optional
from fastapi import APIRouter, Request
from pydantic import BaseModel, Field
import logging

from ..services import ws_manager

router = APIRouter(prefix="/api/notifications", tags=["notifications"])

logger = logging.getLogger(__name__)


class NotificationType(str, Enum):
    """
    Supported notification types.

    Extend this enum to add new notification types.
    Each type can have custom handling logic in NotificationService.
    """

    TASK_COMPLETE = "task_complete"  # Claude completed a task (Stop hook)
    TASK_ERROR = "task_error"  # Task failed with error
    PERMISSION_REQUIRED = "permission_required"  # Claude needs user permission
    SESSION_IDLE = "session_idle"  # Session has been idle
    CUSTOM = "custom"  # Custom notification type for extensibility


class NotificationPriority(str, Enum):
    """
    Notification priority levels.

    Used by clients to determine notification urgency.
    """

    LOW = "low"
    NORMAL = "normal"
    HIGH = "high"
    URGENT = "urgent"


class NotificationRequest(BaseModel):
    """
    Request model for incoming notifications from Claude Code hooks.

    Attributes:
        type: The notification type (see NotificationType enum)
        message: Human-readable notification message
        session_id: Optional session ID for session-specific notifications
        priority: Notification priority (default: normal)
        details: Optional additional data for extensibility
        sound: Whether to play a sound (hint for client)
    """

    type: str = Field(..., description="Notification type (e.g., task_complete)")
    message: str = Field(..., description="Notification message to display")
    session_id: Optional[str] = Field(None, description="Related session ID")
    priority: NotificationPriority = Field(
        NotificationPriority.NORMAL, description="Notification priority"
    )
    details: Optional[dict] = Field(None, description="Additional notification data")
    sound: bool = Field(True, description="Whether to play notification sound")


class NotificationResponse(BaseModel):
    """Response model for notification API."""

    success: bool
    notification_id: str
    timestamp: str


class NotificationService:
    """
    Service for handling notifications.

    This class encapsulates notification logic and provides
    extension points for custom notification handling.

    Usage:
        service = NotificationService()
        await service.send(notification)

    Extension:
        Override _handle_* methods to customize behavior for specific types.
    """

    def __init__(self):
        self._handlers = {
            NotificationType.TASK_COMPLETE: self._handle_task_complete,
            NotificationType.TASK_ERROR: self._handle_task_error,
            NotificationType.PERMISSION_REQUIRED: self._handle_permission_required,
            NotificationType.SESSION_IDLE: self._handle_session_idle,
        }

    async def send(self, notification: NotificationRequest) -> str:
        """
        Process and broadcast a notification.

        Args:
            notification: The notification to send

        Returns:
            notification_id: Unique ID for tracking

        Raises:
            Exception: If broadcast fails
        """
        notification_id = self._generate_id()
        timestamp = datetime.now().isoformat()

        # Call type-specific handler if exists
        handler = self._handlers.get(notification.type)
        if handler:
            await handler(notification)

        # Build WebSocket message
        ws_message = {
            "type": "notification",
            "data": {
                "notificationId": notification_id,
                "notificationType": notification.type,
                "message": notification.message,
                "sessionId": notification.session_id,
                "priority": notification.priority,
                "details": notification.details,
                "sound": notification.sound,
                "timestamp": timestamp,
            },
        }

        # Broadcast to all connected clients
        await ws_manager.broadcast_all(ws_message)

        logger.info(
            f"Notification sent: id={notification_id}, type={notification.type}"
        )

        return notification_id

    def _generate_id(self) -> str:
        """Generate a unique notification ID."""
        import uuid

        return f"notif_{uuid.uuid4().hex[:12]}"

    async def _handle_task_complete(self, notification: NotificationRequest) -> None:
        """Handle task completion notifications. Override for custom behavior."""
        logger.debug(f"Task complete: {notification.message}")

    async def _handle_task_error(self, notification: NotificationRequest) -> None:
        """Handle task error notifications. Override for custom behavior."""
        logger.warning(f"Task error: {notification.message}")

    async def _handle_permission_required(
        self, notification: NotificationRequest
    ) -> None:
        """Handle permission request notifications. Override for custom behavior."""
        logger.info(f"Permission required: {notification.message}")

    async def _handle_session_idle(self, notification: NotificationRequest) -> None:
        """Handle session idle notifications. Override for custom behavior."""
        logger.debug(f"Session idle: {notification.message}")


# Singleton instance
notification_service = NotificationService()


@router.post("", response_model=NotificationResponse)
async def send_notification(
    notification: NotificationRequest,
    request: Request,
):
    """
    Receive notification from Claude Code hooks and broadcast to all connected clients.

    This endpoint is called by Claude Code's Stop hook when a task completes.
    It broadcasts the notification to all connected WebSocket clients.

    Note: This endpoint does not require authentication since it's called by local
    Claude Code hooks. The hook runs on the same machine as the server.

    Example hook configuration:
    ```json
    {
      "hooks": {
        "Stop": [{
          "hooks": [{
            "type": "command",
            "command": "curl -X POST http://localhost:8765/api/notifications ..."
          }]
        }]
      }
    }
    ```
    """
    logger.info(
        f"Received notification: type={notification.type}, "
        f"message={notification.message}, priority={notification.priority}"
    )

    notification_id = await notification_service.send(notification)

    return NotificationResponse(
        success=True,
        notification_id=notification_id,
        timestamp=datetime.now().isoformat(),
    )


@router.get("/types")
async def list_notification_types():
    """
    List all supported notification types.

    Useful for clients to discover available notification types
    and for documentation purposes.
    """
    return {
        "types": [t.value for t in NotificationType],
        "priorities": [p.value for p in NotificationPriority],
    }
