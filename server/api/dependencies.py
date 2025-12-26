"""Authentication dependencies for FastAPI routes."""

import logging
from typing import Optional

from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from ..models.device import Device, TrustLevel
from ..models.audit import AuditAction, AuditLogCreate, AuditResult, RiskLevel
from ..services.auth_service import auth_service

logger = logging.getLogger(__name__)

# Bearer token security scheme
bearer_scheme = HTTPBearer(auto_error=False)


def get_client_ip(request: Request) -> str:
    """Get client IP address from request."""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()

    cf_ip = request.headers.get("CF-Connecting-IP")
    if cf_ip:
        return cf_ip

    return request.client.host if request.client else "unknown"


async def get_current_device(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
) -> Optional[Device]:
    """
    Get the current device from the access token.

    Returns None if:
    - No token provided
    - Token is invalid
    - Device not found or inactive

    Does NOT raise an exception - use require_auth for protected routes.
    """
    if not credentials:
        return None

    token = credentials.credentials
    payload = auth_service.verify_access_token(token)

    if not payload:
        return None

    device_id = payload.get("sub")
    if not device_id:
        return None

    device = auth_service.get_device(device_id)
    if not device or not device.is_active:
        return None

    # Verify fingerprint if provided
    fingerprint = request.headers.get("X-Device-Fingerprint")
    if fingerprint and not auth_service.verify_fingerprint(device, fingerprint):
        logger.warning(f"Fingerprint mismatch for device {device_id}")
        return None

    return device


async def require_auth(
    request: Request,
    device: Optional[Device] = Depends(get_current_device),
) -> Device:
    """
    Require authentication for a route.

    Raises HTTPException 401 if not authenticated.
    """
    if not device:
        auth_service.log_audit(
            AuditLogCreate(
                ip=get_client_ip(request),
                action=AuditAction.AUTH_FAILED,
                details={"reason": "Missing or invalid token"},
                result=AuditResult.BLOCKED,
            )
        )
        raise HTTPException(
            status_code=401,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return device


async def require_local_or_auth(
    request: Request,
    device: Optional[Device] = Depends(get_current_device),
) -> Optional[Device]:
    """
    Allow access if request is local OR authenticated.

    This is for routes that should be accessible from Desktop app without auth,
    but require auth from remote devices.
    """
    client_ip = get_client_ip(request)

    # Allow local access without auth
    if client_ip in ("127.0.0.1", "localhost", "::1"):
        return device  # May be None for local requests

    # Remote access requires auth
    if not device:
        auth_service.log_audit(
            AuditLogCreate(
                ip=client_ip,
                action=AuditAction.AUTH_FAILED,
                details={"reason": "Remote access without auth"},
                result=AuditResult.BLOCKED,
            )
        )
        raise HTTPException(
            status_code=401,
            detail="Authentication required for remote access",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return device


def check_trust_level(required_level: TrustLevel):
    """
    Create a dependency that checks if device has required trust level.

    Usage:
        @router.post("/dangerous")
        async def dangerous_action(
            device: Device = Depends(require_auth),
            _: None = Depends(check_trust_level(TrustLevel.FULL))
        ):
            ...
    """

    async def checker(
        request: Request,
        device: Device = Depends(require_auth),
    ):
        trust_levels = {
            TrustLevel.VIEW_ONLY: 0,
            TrustLevel.PARTIAL: 1,
            TrustLevel.FULL: 2,
        }

        device_level = trust_levels.get(device.trust_level, 0)
        required = trust_levels.get(required_level, 2)

        if device_level < required:
            auth_service.log_audit(
                AuditLogCreate(
                    device_id=device.id,
                    device_name=device.name,
                    ip=get_client_ip(request),
                    action=AuditAction.AUTH_FAILED,
                    details={
                        "reason": "Insufficient trust level",
                        "required": required_level,
                        "actual": device.trust_level,
                    },
                    result=AuditResult.BLOCKED,
                )
            )
            raise HTTPException(
                status_code=403,
                detail=f"Insufficient trust level. Required: {required_level}",
            )

        return None

    return checker


class AuthContext:
    """Context object containing authentication info for a request."""

    def __init__(
        self,
        device: Optional[Device],
        ip: str,
        is_local: bool,
    ):
        self.device = device
        self.ip = ip
        self.is_local = is_local

    @property
    def is_authenticated(self) -> bool:
        return self.device is not None

    @property
    def trust_level(self) -> TrustLevel:
        if self.device:
            return self.device.trust_level
        if self.is_local:
            return TrustLevel.FULL
        return TrustLevel.VIEW_ONLY

    def can_perform(self, risk_level: RiskLevel) -> bool:
        """Check if the current context can perform an action of given risk level."""
        if self.is_local:
            return True

        if not self.device:
            return False

        if risk_level == RiskLevel.LOW:
            return True

        if risk_level == RiskLevel.MEDIUM:
            return self.device.trust_level in (TrustLevel.PARTIAL, TrustLevel.FULL)

        if risk_level == RiskLevel.HIGH:
            return self.device.trust_level == TrustLevel.FULL

        return False


async def get_auth_context(
    request: Request,
    device: Optional[Device] = Depends(get_current_device),
) -> AuthContext:
    """Get authentication context for the current request."""
    ip = get_client_ip(request)
    is_local = ip in ("127.0.0.1", "localhost", "::1")

    return AuthContext(
        device=device,
        ip=ip,
        is_local=is_local,
    )
