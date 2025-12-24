"""WebSocket API endpoint."""

import uuid
import asyncio
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import logging

from ..services import ws_manager, output_monitor

logger = logging.getLogger(__name__)

router = APIRouter()


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time updates."""
    connection_id = str(uuid.uuid4())

    await ws_manager.connect(websocket, connection_id)

    try:
        while True:
            data = await websocket.receive_json()
            await ws_manager.handle_message(connection_id, data)
    except WebSocketDisconnect:
        ws_manager.disconnect(connection_id)
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        ws_manager.disconnect(connection_id)
