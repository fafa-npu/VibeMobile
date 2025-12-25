"""Session management API routes."""

import os
import uuid
from fastapi import APIRouter, HTTPException, UploadFile, File
from datetime import datetime

from ..models import Session, Command
from ..services import tmux_manager, output_monitor

router = APIRouter(prefix="/api/sessions", tags=["sessions"])

# Upload directory for images
UPLOAD_DIR = "/tmp/vibe-uploads"


@router.get("", response_model=list[Session])
async def list_sessions():
    """Get all vibe sessions."""
    return tmux_manager.list_sessions()


@router.get("/{session_id}", response_model=Session)
async def get_session(session_id: str):
    """Get a specific session by ID."""
    session = tmux_manager.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found")
    return session


@router.get("/{session_id}/output")
async def get_session_output(session_id: str, with_ansi: bool = False):
    """Get the full output of a session."""
    if not tmux_manager.session_exists(session_id):
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found")

    output = tmux_manager.capture_output(session_id, with_ansi=with_ansi)
    if output is None:
        raise HTTPException(status_code=500, detail="Failed to capture output")

    return {
        "session_id": session_id,
        "output": output,
        "timestamp": datetime.now().isoformat(),
    }


@router.post("/{session_id}/send", response_model=Command)
async def send_command(session_id: str, content: str, press_enter: bool = True):
    """Send a command to a session."""
    if not tmux_manager.session_exists(session_id):
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found")

    command = Command(session_id=session_id, content=content)

    success = tmux_manager.send_keys(session_id, content, press_enter=press_enter)

    if success:
        command.status = "sent"
        command.sent_at = datetime.now()
    else:
        command.status = "failed"
        command.error = "Failed to send keys to tmux session"
        raise HTTPException(status_code=500, detail=command.error)

    return command


@router.post("/{session_id}/key")
async def send_special_key(session_id: str, key: str):
    """Send a special key to a session (e.g., C-c for Ctrl+C)."""
    if not tmux_manager.session_exists(session_id):
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found")

    success = tmux_manager.send_special_key(session_id, key)

    if not success:
        raise HTTPException(status_code=500, detail="Failed to send key")

    return {"success": True, "key": key, "session_id": session_id}


@router.post("", response_model=Session)
async def create_session(command: str = "claude"):
    """Create a new tmux session running Claude."""
    session_name = tmux_manager.create_session(command=command)

    if not session_name:
        raise HTTPException(status_code=500, detail="Failed to create session")

    # Start monitoring the new session
    await output_monitor.start_monitoring(session_name)

    session = tmux_manager.get_session(session_name)
    if not session:
        raise HTTPException(status_code=500, detail="Session created but not found")

    return session


@router.delete("/{session_id}")
async def kill_session(session_id: str):
    """Kill a session."""
    if not tmux_manager.session_exists(session_id):
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found")

    # Stop monitoring
    await output_monitor.stop_monitoring(session_id)

    success = tmux_manager.kill_session(session_id)

    if not success:
        raise HTTPException(status_code=500, detail="Failed to kill session")

    return {"success": True, "session_id": session_id}


@router.post("/{session_id}/upload")
async def upload_file(session_id: str, file: UploadFile = File(...)):
    """Upload a file (image) and send its path to the session."""
    if not tmux_manager.session_exists(session_id):
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found")

    # Validate file type (images only)
    allowed_types = ["image/png", "image/jpeg", "image/gif", "image/webp"]
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed: {', '.join(allowed_types)}"
        )

    # Create upload directory
    session_dir = os.path.join(UPLOAD_DIR, session_id)
    os.makedirs(session_dir, exist_ok=True)

    # Generate unique filename
    ext = os.path.splitext(file.filename or "image.png")[1]
    unique_name = f"{uuid.uuid4().hex}{ext}"
    file_path = os.path.join(session_dir, unique_name)

    # Save file
    content = await file.read()
    with open(file_path, "wb") as f:
        f.write(content)

    # First clear any existing input with Escape
    tmux_manager.send_special_key(session_id, "Escape")

    # Send file path to Claude using @ syntax (without Enter - let Claude handle the file reference)
    success = tmux_manager.send_keys(session_id, f"@{file_path}", press_enter=False)

    if not success:
        raise HTTPException(status_code=500, detail="Failed to send file path")

    return {
        "success": True,
        "session_id": session_id,
        "path": file_path,
        "filename": file.filename,
    }
