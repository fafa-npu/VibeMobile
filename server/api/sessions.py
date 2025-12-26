"""Session management API routes."""

import os
import uuid
from fastapi import APIRouter, HTTPException, UploadFile, File, Depends, Request
from datetime import datetime

from ..models import Session, Command
from ..models.audit import (
    AuditAction,
    AuditLogCreate,
    AuditResult,
    RiskLevel,
    is_high_risk_key,
)
from ..services import tmux_manager, output_monitor, auth_service
from .dependencies import (
    require_local_or_auth,
    get_auth_context,
    AuthContext,
    get_client_ip,
)

router = APIRouter(prefix="/api/sessions", tags=["sessions"])

# Upload directory for images
UPLOAD_DIR = "/tmp/vibe-uploads"


@router.get("", response_model=list[Session])
async def list_sessions(
    request: Request,
    auth: AuthContext = Depends(get_auth_context),
):
    """Get all vibe sessions. (LOW risk - view only)"""
    # List sessions is LOW risk, allow local or authenticated
    if not auth.is_local and not auth.is_authenticated:
        auth_service.log_audit(
            AuditLogCreate(
                ip=auth.ip,
                action=AuditAction.AUTH_FAILED,
                details={"reason": "Unauthenticated remote access", "endpoint": "list_sessions"},
                result=AuditResult.BLOCKED,
            )
        )
        raise HTTPException(status_code=401, detail="Authentication required")

    return tmux_manager.list_sessions()


@router.get("/{session_id}", response_model=Session)
async def get_session(
    session_id: str,
    request: Request,
    auth: AuthContext = Depends(get_auth_context),
):
    """Get a specific session by ID. (LOW risk - view only)"""
    if not auth.is_local and not auth.is_authenticated:
        raise HTTPException(status_code=401, detail="Authentication required")

    session = tmux_manager.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found")
    return session


@router.get("/{session_id}/output")
async def get_session_output(
    session_id: str,
    with_ansi: bool = False,
    request: Request = None,
    auth: AuthContext = Depends(get_auth_context),
):
    """Get the full output of a session. (LOW risk - view only)"""
    if not auth.is_local and not auth.is_authenticated:
        raise HTTPException(status_code=401, detail="Authentication required")

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
async def send_command(
    session_id: str,
    content: str,
    press_enter: bool = True,
    request: Request = None,
    auth: AuthContext = Depends(get_auth_context),
):
    """Send a command to a session. (MEDIUM risk - sends input)"""
    # Check permission
    if not auth.can_perform(RiskLevel.MEDIUM):
        auth_service.log_audit(
            AuditLogCreate(
                device_id=auth.device.id if auth.device else None,
                device_name=auth.device.name if auth.device else None,
                ip=auth.ip,
                action=AuditAction.SEND_MESSAGE,
                details={
                    "session_id": session_id,
                    "reason": "Insufficient permission",
                    "content_preview": content[:50] if content else "",
                },
                result=AuditResult.BLOCKED,
            )
        )
        raise HTTPException(
            status_code=403,
            detail="Insufficient permission to send commands",
        )

    if not tmux_manager.session_exists(session_id):
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found")

    command = Command(session_id=session_id, content=content)

    success = tmux_manager.send_keys(session_id, content, press_enter=press_enter)

    if success:
        command.status = "sent"
        command.sent_at = datetime.now()

        # Log successful command
        auth_service.log_audit(
            AuditLogCreate(
                device_id=auth.device.id if auth.device else None,
                device_name=auth.device.name if auth.device else None,
                ip=auth.ip,
                action=AuditAction.SEND_MESSAGE,
                details={
                    "session_id": session_id,
                    "content_preview": content[:100] if content else "",
                },
                result=AuditResult.SUCCESS,
            )
        )
    else:
        command.status = "failed"
        command.error = "Failed to send keys to tmux session"
        raise HTTPException(status_code=500, detail=command.error)

    return command


@router.post("/{session_id}/key")
async def send_special_key(
    session_id: str,
    key: str,
    request: Request = None,
    auth: AuthContext = Depends(get_auth_context),
):
    """Send a special key to a session (e.g., C-c for Ctrl+C).

    Risk level depends on the key:
    - HIGH risk: C-c (Ctrl+C), C-d (Ctrl+D), C-z (Ctrl+Z)
    - MEDIUM risk: other keys
    """
    # Determine risk level based on key
    risk_level = RiskLevel.HIGH if is_high_risk_key(key) else RiskLevel.MEDIUM

    if not auth.can_perform(risk_level):
        auth_service.log_audit(
            AuditLogCreate(
                device_id=auth.device.id if auth.device else None,
                device_name=auth.device.name if auth.device else None,
                ip=auth.ip,
                action=AuditAction.SEND_KEY,
                details={
                    "session_id": session_id,
                    "key": key,
                    "reason": "Insufficient permission",
                    "risk_level": risk_level,
                },
                result=AuditResult.BLOCKED,
            )
        )
        raise HTTPException(
            status_code=403,
            detail=f"Insufficient permission for {'high-risk' if risk_level == RiskLevel.HIGH else 'this'} key operation",
        )

    if not tmux_manager.session_exists(session_id):
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found")

    success = tmux_manager.send_special_key(session_id, key)

    if not success:
        raise HTTPException(status_code=500, detail="Failed to send key")

    # Log successful key send
    auth_service.log_audit(
        AuditLogCreate(
            device_id=auth.device.id if auth.device else None,
            device_name=auth.device.name if auth.device else None,
            ip=auth.ip,
            action=AuditAction.SEND_KEY,
            details={"session_id": session_id, "key": key, "risk_level": risk_level},
            result=AuditResult.SUCCESS,
        )
    )

    return {"success": True, "key": key, "session_id": session_id}


@router.post("", response_model=Session)
async def create_session(
    command: str = "claude",
    request: Request = None,
    auth: AuthContext = Depends(get_auth_context),
):
    """Create a new tmux session running Claude. (HIGH risk - creates new process)"""
    if not auth.can_perform(RiskLevel.HIGH):
        auth_service.log_audit(
            AuditLogCreate(
                device_id=auth.device.id if auth.device else None,
                device_name=auth.device.name if auth.device else None,
                ip=auth.ip,
                action=AuditAction.SESSION_CREATE,
                details={"command": command, "reason": "Insufficient permission"},
                result=AuditResult.BLOCKED,
            )
        )
        raise HTTPException(
            status_code=403,
            detail="Insufficient permission to create sessions",
        )

    session_name = tmux_manager.create_session(command=command)

    if not session_name:
        raise HTTPException(status_code=500, detail="Failed to create session")

    # Start monitoring the new session
    await output_monitor.start_monitoring(session_name)

    session = tmux_manager.get_session(session_name)
    if not session:
        raise HTTPException(status_code=500, detail="Session created but not found")

    # Log successful creation
    auth_service.log_audit(
        AuditLogCreate(
            device_id=auth.device.id if auth.device else None,
            device_name=auth.device.name if auth.device else None,
            ip=auth.ip,
            action=AuditAction.SESSION_CREATE,
            details={"session_id": session_name, "command": command},
            result=AuditResult.SUCCESS,
        )
    )

    return session


@router.delete("/{session_id}")
async def kill_session(
    session_id: str,
    request: Request = None,
    auth: AuthContext = Depends(get_auth_context),
):
    """Kill a session. (HIGH risk - terminates process)"""
    if not auth.can_perform(RiskLevel.HIGH):
        auth_service.log_audit(
            AuditLogCreate(
                device_id=auth.device.id if auth.device else None,
                device_name=auth.device.name if auth.device else None,
                ip=auth.ip,
                action=AuditAction.SESSION_KILL,
                details={"session_id": session_id, "reason": "Insufficient permission"},
                result=AuditResult.BLOCKED,
            )
        )
        raise HTTPException(
            status_code=403,
            detail="Insufficient permission to kill sessions",
        )

    if not tmux_manager.session_exists(session_id):
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found")

    # Stop monitoring
    await output_monitor.stop_monitoring(session_id)

    success = tmux_manager.kill_session(session_id)

    if not success:
        raise HTTPException(status_code=500, detail="Failed to kill session")

    # Log successful kill
    auth_service.log_audit(
        AuditLogCreate(
            device_id=auth.device.id if auth.device else None,
            device_name=auth.device.name if auth.device else None,
            ip=auth.ip,
            action=AuditAction.SESSION_KILL,
            details={"session_id": session_id},
            result=AuditResult.SUCCESS,
        )
    )

    return {"success": True, "session_id": session_id}


@router.post("/{session_id}/upload")
async def upload_file(
    session_id: str,
    file: UploadFile = File(...),
    request: Request = None,
    auth: AuthContext = Depends(get_auth_context),
):
    """Upload a file (image) and send its path to the session. (MEDIUM risk - file upload)"""
    if not auth.can_perform(RiskLevel.MEDIUM):
        auth_service.log_audit(
            AuditLogCreate(
                device_id=auth.device.id if auth.device else None,
                device_name=auth.device.name if auth.device else None,
                ip=auth.ip,
                action=AuditAction.FILE_UPLOAD,
                details={
                    "session_id": session_id,
                    "filename": file.filename,
                    "reason": "Insufficient permission",
                },
                result=AuditResult.BLOCKED,
            )
        )
        raise HTTPException(
            status_code=403,
            detail="Insufficient permission to upload files",
        )

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

    # Log successful upload
    auth_service.log_audit(
        AuditLogCreate(
            device_id=auth.device.id if auth.device else None,
            device_name=auth.device.name if auth.device else None,
            ip=auth.ip,
            action=AuditAction.FILE_UPLOAD,
            details={
                "session_id": session_id,
                "filename": file.filename,
                "path": file_path,
            },
            result=AuditResult.SUCCESS,
        )
    )

    return {
        "success": True,
        "session_id": session_id,
        "path": file_path,
        "filename": file.filename,
    }
