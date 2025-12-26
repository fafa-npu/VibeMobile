"""Authentication API routes for device pairing and token management."""

import asyncio
import logging
import re
import uuid
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from ..config import settings
from ..models.device import DeviceCreate, DeviceInfo, PairingRequest, TrustLevel
from ..models.audit import AuditAction, AuditLogCreate, AuditResult
from ..services import auth_service, ws_manager

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/auth", tags=["auth"])


# ==================== Request/Response Models ====================


class PairingInitResponse(BaseModel):
    """Response for pairing initiation."""

    code: str
    expires_in: int  # seconds


class PairingCompleteRequest(BaseModel):
    """Request to complete device pairing."""

    code: str
    fingerprint: str


class PairingCompleteResponse(BaseModel):
    """Response for successful pairing."""

    device_id: str
    message: str


class TokenRefreshResponse(BaseModel):
    """Response for token refresh."""

    access_token: str
    expires_in: int  # seconds
    device_id: str
    trust_level: str


class DeviceTrustUpdateRequest(BaseModel):
    """Request to update device trust level."""

    trust_level: TrustLevel


class ApprovalRequest(BaseModel):
    """Request for Desktop approval."""

    approval_id: str
    action: str  # "approve" or "reject"


# ==================== Helper Functions ====================


def parse_user_agent(user_agent: str) -> tuple[str, str, str]:
    """Parse User-Agent string to extract device name, browser, and OS."""
    # Simple parsing - can be improved with user-agents library
    browser = "Unknown"
    os_name = "Unknown"
    device_name = "Unknown Device"

    # Detect browser
    if "Chrome" in user_agent and "Safari" in user_agent:
        match = re.search(r"Chrome/(\d+)", user_agent)
        browser = f"Chrome {match.group(1)}" if match else "Chrome"
    elif "Safari" in user_agent and "Chrome" not in user_agent:
        browser = "Safari"
    elif "Firefox" in user_agent:
        browser = "Firefox"
    elif "Edge" in user_agent:
        browser = "Edge"

    # Detect OS
    if "iPhone" in user_agent:
        os_name = "iOS"
        device_name = "iPhone"
    elif "iPad" in user_agent:
        os_name = "iPadOS"
        device_name = "iPad"
    elif "Android" in user_agent:
        os_name = "Android"
        device_name = "Android Device"
    elif "Mac OS X" in user_agent or "Macintosh" in user_agent:
        os_name = "macOS"
        device_name = "Mac"
    elif "Windows" in user_agent:
        os_name = "Windows"
        device_name = "Windows PC"
    elif "Linux" in user_agent:
        os_name = "Linux"
        device_name = "Linux PC"

    # Create device name
    device_name = f"{device_name} ({browser})"

    return device_name, browser, os_name


def get_client_ip(request: Request) -> str:
    """Get client IP address from request."""
    # Check for forwarded headers (when behind proxy/Cloudflare)
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()

    cf_ip = request.headers.get("CF-Connecting-IP")
    if cf_ip:
        return cf_ip

    return request.client.host if request.client else "unknown"


def get_fingerprint_from_request(request: Request) -> Optional[str]:
    """Get device fingerprint from request header."""
    return request.headers.get("X-Device-Fingerprint")


# ==================== Pairing Endpoints ====================


@router.post("/pair/initiate", response_model=PairingInitResponse)
async def initiate_pairing(request: Request):
    """
    Initiate device pairing by generating a pairing code.
    Called by Desktop app to start the pairing process.
    """
    # Only allow from localhost (Desktop app)
    client_ip = get_client_ip(request)
    if client_ip not in ("127.0.0.1", "localhost", "::1"):
        # Log attempt
        auth_service.log_audit(
            AuditLogCreate(
                ip=client_ip,
                action=AuditAction.AUTH_FAILED,
                details={"reason": "Pairing initiate from non-local IP"},
                result=AuditResult.BLOCKED,
            )
        )
        raise HTTPException(status_code=403, detail="Pairing can only be initiated locally")

    pairing_code = auth_service.generate_pairing_code()

    return PairingInitResponse(
        code=pairing_code.code,
        expires_in=300,  # 5 minutes
    )


@router.post("/pair/complete")
async def complete_pairing(
    request: Request,
    data: PairingCompleteRequest,
    response: Response,
):
    """
    Complete device pairing.
    Called by mobile device after entering pairing code.
    """
    # Verify pairing code
    if not auth_service.verify_pairing_code(data.code):
        auth_service.log_audit(
            AuditLogCreate(
                ip=get_client_ip(request),
                action=AuditAction.AUTH_FAILED,
                details={"reason": "Invalid or expired pairing code"},
                result=AuditResult.FAILED,
            )
        )
        raise HTTPException(status_code=401, detail="Invalid or expired pairing code")

    # Parse device info from User-Agent
    user_agent = request.headers.get("User-Agent", "Unknown")
    device_name, browser, os_name = parse_user_agent(user_agent)
    client_ip = get_client_ip(request)

    # Create approval request for Desktop
    approval_id = str(uuid.uuid4())
    approval_data = {
        "type": "pairing_request",
        "approval_id": approval_id,
        "fingerprint": data.fingerprint,
        "device_name": device_name,
        "browser": browser,
        "os": os_name,
        "ip": client_ip,
        "user_agent": user_agent,
        "timestamp": datetime.now().isoformat(),
    }

    auth_service.request_approval(approval_id, approval_data)

    # Send to Desktop via WebSocket
    await ws_manager.broadcast_to_desktop({
        "type": "pairing_request",
        "data": approval_data,
    })

    # Wait for Desktop approval (up to 60 seconds)
    approved = await wait_for_approval(approval_id, timeout=60)

    if not approved:
        auth_service.log_audit(
            AuditLogCreate(
                ip=client_ip,
                action=AuditAction.AUTH_FAILED,
                details={
                    "reason": "Pairing rejected or timed out",
                    "device_name": device_name,
                },
                result=AuditResult.BLOCKED,
            )
        )
        raise HTTPException(status_code=403, detail="Pairing request rejected or timed out")

    # Mark code as used
    auth_service.mark_code_used(data.code)

    # Create device
    device = auth_service.create_device(
        DeviceCreate(
            fingerprint=data.fingerprint,
            name=device_name,
            browser=browser,
            os=os_name,
            ip=client_ip,
        )
    )

    # Create refresh token
    refresh_token = auth_service.create_refresh_token(device.id)

    # Log successful pairing
    auth_service.log_audit(
        AuditLogCreate(
            device_id=device.id,
            device_name=device.name,
            ip=client_ip,
            action=AuditAction.DEVICE_PAIRED,
            details={"browser": browser, "os": os_name},
            result=AuditResult.SUCCESS,
        )
    )

    # Set refresh token as HttpOnly cookie
    json_response = JSONResponse(
        content={
            "device_id": device.id,
            "message": "Device paired successfully",
        }
    )
    json_response.set_cookie(
        key="refresh_token",
        value=refresh_token,
        httponly=True,
        secure=True,  # Always require HTTPS - use local HTTPS for dev
        samesite="strict",
        max_age=30 * 24 * 3600,  # 30 days
        path="/api/auth",
    )

    return json_response


async def wait_for_approval(approval_id: str, timeout: int = 60) -> bool:
    """Wait for Desktop approval of a request."""
    start_time = datetime.now()

    while (datetime.now() - start_time).total_seconds() < timeout:
        approval = auth_service.get_pending_approval(approval_id)
        if approval:
            status = approval.get("status")
            if status == "approved":
                return True
            elif status == "rejected":
                return False
        await asyncio.sleep(0.5)

    return False


# ==================== Token Endpoints ====================


@router.post("/refresh", response_model=TokenRefreshResponse)
async def refresh_token(request: Request):
    """
    Refresh access token using refresh token from cookie.
    """
    refresh_token = request.cookies.get("refresh_token")
    if not refresh_token:
        raise HTTPException(status_code=401, detail="No refresh token")

    # Verify refresh token
    device = auth_service.verify_refresh_token(refresh_token)
    if not device:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    # Verify device fingerprint
    fingerprint = get_fingerprint_from_request(request)
    if fingerprint and not auth_service.verify_fingerprint(device, fingerprint):
        auth_service.log_audit(
            AuditLogCreate(
                device_id=device.id,
                device_name=device.name,
                ip=get_client_ip(request),
                action=AuditAction.AUTH_FAILED,
                details={"reason": "Fingerprint mismatch"},
                result=AuditResult.BLOCKED,
            )
        )
        raise HTTPException(status_code=401, detail="Device fingerprint mismatch")

    # Update device activity
    auth_service.update_device_activity(device.id, get_client_ip(request))

    # Create new access token
    access_token, expires_in = auth_service.create_access_token(device.id)

    # Log token refresh
    auth_service.log_audit(
        AuditLogCreate(
            device_id=device.id,
            device_name=device.name,
            ip=get_client_ip(request),
            action=AuditAction.TOKEN_REFRESHED,
            result=AuditResult.SUCCESS,
        )
    )

    return TokenRefreshResponse(
        access_token=access_token,
        expires_in=expires_in,
        device_id=device.id,
        trust_level=device.trust_level,
    )


@router.post("/logout")
async def logout(request: Request, response: Response):
    """
    Logout - invalidate refresh token.
    """
    refresh_token = request.cookies.get("refresh_token")
    if refresh_token:
        device = auth_service.verify_refresh_token(refresh_token)
        if device:
            # Invalidate the refresh token
            device.refresh_token_hash = None
            auth_service._save_devices()

            auth_service.log_audit(
                AuditLogCreate(
                    device_id=device.id,
                    device_name=device.name,
                    ip=get_client_ip(request),
                    action=AuditAction.DEVICE_REVOKED,
                    details={"reason": "User logout"},
                    result=AuditResult.SUCCESS,
                )
            )

    # Clear cookie
    response = JSONResponse(content={"message": "Logged out"})
    response.delete_cookie("refresh_token", path="/api/auth")
    return response


# ==================== Device Management Endpoints ====================


@router.get("/devices", response_model=list[DeviceInfo])
async def list_devices(request: Request):
    """
    List all registered devices.
    Only accessible from localhost (Desktop app).
    """
    client_ip = get_client_ip(request)
    if client_ip not in ("127.0.0.1", "localhost", "::1"):
        raise HTTPException(status_code=403, detail="Only accessible locally")

    return auth_service.list_devices()


@router.put("/devices/{device_id}/trust")
async def update_device_trust(
    device_id: str,
    data: DeviceTrustUpdateRequest,
    request: Request,
):
    """
    Update device trust level.
    Only accessible from localhost (Desktop app).
    """
    client_ip = get_client_ip(request)
    if client_ip not in ("127.0.0.1", "localhost", "::1"):
        raise HTTPException(status_code=403, detail="Only accessible locally")

    if not auth_service.update_device_trust_level(device_id, data.trust_level):
        raise HTTPException(status_code=404, detail="Device not found")

    return {"message": "Trust level updated", "device_id": device_id}


@router.delete("/devices/{device_id}")
async def revoke_device(device_id: str, request: Request):
    """
    Revoke a device's access.
    Only accessible from localhost (Desktop app).
    """
    client_ip = get_client_ip(request)
    if client_ip not in ("127.0.0.1", "localhost", "::1"):
        raise HTTPException(status_code=403, detail="Only accessible locally")

    device = auth_service.get_device(device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    auth_service.revoke_device(device_id)

    auth_service.log_audit(
        AuditLogCreate(
            device_id=device_id,
            device_name=device.name,
            ip=client_ip,
            action=AuditAction.DEVICE_REVOKED,
            details={"reason": "Manual revocation"},
            result=AuditResult.SUCCESS,
        )
    )

    return {"message": "Device revoked", "device_id": device_id}


# ==================== Approval Endpoints ====================


@router.post("/approve")
async def handle_approval(data: ApprovalRequest, request: Request):
    """
    Handle approval/rejection from Desktop app.
    Only accessible from localhost.
    """
    client_ip = get_client_ip(request)
    if client_ip not in ("127.0.0.1", "localhost", "::1"):
        raise HTTPException(status_code=403, detail="Only accessible locally")

    approval = auth_service.get_pending_approval(data.approval_id)
    if not approval:
        raise HTTPException(status_code=404, detail="Approval request not found")

    if data.action == "approve":
        auth_service.approve_request(data.approval_id)
        return {"message": "Request approved"}
    elif data.action == "reject":
        auth_service.reject_request(data.approval_id)
        return {"message": "Request rejected"}
    else:
        raise HTTPException(status_code=400, detail="Invalid action")


# ==================== Status Endpoint ====================


@router.get("/status")
async def auth_status(request: Request):
    """
    Check authentication status.
    Returns whether the request has a valid refresh token.
    """
    refresh_token = request.cookies.get("refresh_token")
    if not refresh_token:
        return {"authenticated": False, "reason": "No refresh token"}

    device = auth_service.verify_refresh_token(refresh_token)
    if not device:
        return {"authenticated": False, "reason": "Invalid refresh token"}

    return {
        "authenticated": True,
        "device_id": device.id,
        "device_name": device.name,
        "trust_level": device.trust_level,
    }
