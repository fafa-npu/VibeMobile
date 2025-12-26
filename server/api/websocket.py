"""WebSocket API endpoint."""

import uuid
import asyncio
from typing import Optional
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
import logging

from ..services import ws_manager, output_monitor, auth_service

logger = logging.getLogger(__name__)

router = APIRouter()


def get_client_ip_from_websocket(websocket: WebSocket) -> str:
    """Get client IP address from WebSocket connection."""
    # Check for forwarded headers
    forwarded = websocket.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()

    cf_ip = websocket.headers.get("CF-Connecting-IP")
    if cf_ip:
        return cf_ip

    return websocket.client.host if websocket.client else "unknown"


@router.websocket("/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    token: Optional[str] = Query(None),
):
    """WebSocket endpoint for real-time updates.

    Authentication:
    - Local connections (127.0.0.1, localhost, ::1): No auth required
    - Remote connections: Must provide valid access token via query param

    Query params:
    - token: Access token for remote authentication
    """
    connection_id = str(uuid.uuid4())
    client_ip = get_client_ip_from_websocket(websocket)
    is_local = client_ip in ("127.0.0.1", "localhost", "::1")

    # Authenticate remote connections
    device = None
    if not is_local:
        if not token:
            await websocket.close(code=4001, reason="Authentication required")
            return

        payload = auth_service.verify_access_token(token)
        if not payload:
            await websocket.close(code=4001, reason="Invalid or expired token")
            return

        device_id = payload.get("sub")
        device = auth_service.get_device(device_id) if device_id else None

        if not device or not device.is_active:
            await websocket.close(code=4001, reason="Device not found or inactive")
            return

        logger.info(f"Remote WebSocket connection from device: {device.name} ({device_id})")

    await ws_manager.connect(websocket, connection_id)

    # Store device info for this connection (for permission checks in messages)
    connection_info = {
        "device": device,
        "is_local": is_local,
        "ip": client_ip,
    }

    try:
        while True:
            data = await websocket.receive_json()
            await ws_manager.handle_message(connection_id, data)
    except WebSocketDisconnect:
        ws_manager.disconnect(connection_id)
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        ws_manager.disconnect(connection_id)
