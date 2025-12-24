"""Configuration management for VibeMobile server."""

from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """Application settings."""

    # Server
    host: str = "0.0.0.0"
    port: int = 8765

    # tmux
    tmux_session_prefix: str = "vibe"
    tmux_capture_history: int = 500  # Lines to capture

    # Monitoring
    monitor_interval: float = 0.5  # Seconds between output checks

    # WebSocket
    ws_heartbeat_interval: float = 30.0  # Seconds

    # Security (for future Cloudflare integration)
    api_key: Optional[str] = None

    class Config:
        env_prefix = "VIBE_"
        env_file = ".env"


settings = Settings()
