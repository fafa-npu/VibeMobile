"""Session management API routes."""

from fastapi import APIRouter, HTTPException
from datetime import datetime

from ..models import Session, Command
from ..services import tmux_manager, output_monitor

router = APIRouter(prefix="/api/sessions", tags=["sessions"])


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
