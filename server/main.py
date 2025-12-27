"""VibeMobile Server - Main entry point."""

import asyncio
import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

from .config import settings
from .api import sessions_router, websocket_router, auth_router, notifications_router
from .services import output_monitor, ws_manager

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    logger.info("Starting VibeMobile server...")

    # Connect output monitor to WebSocket broadcaster
    output_monitor.subscribe(ws_manager.broadcast_output)

    # Start monitoring all existing sessions
    await output_monitor.start_all()

    # Start background task to refresh sessions periodically
    async def refresh_loop():
        while True:
            await asyncio.sleep(5)  # Check for new sessions every 5 seconds
            await output_monitor.refresh_sessions()

    refresh_task = asyncio.create_task(refresh_loop())

    logger.info(f"Server running on https://{settings.host}:{settings.port}")
    yield

    # Shutdown
    logger.info("Shutting down VibeMobile server...")
    refresh_task.cancel()
    try:
        await refresh_task
    except asyncio.CancelledError:
        pass
    await output_monitor.stop_all()


# Create FastAPI app
app = FastAPI(
    title="VibeMobile",
    description="Remote monitoring and control for Claude Code sessions",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict this
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(sessions_router)
app.include_router(websocket_router)
app.include_router(auth_router)
app.include_router(notifications_router)


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "name": "VibeMobile",
        "version": "0.1.0",
        "status": "running",
    }


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "healthy"}


def main():
    """Run the server."""
    # Get project root directory
    project_root = Path(__file__).parent.parent

    # SSL certificate paths
    ssl_certfile = settings.ssl_certfile or str(project_root / "certs" / "localhost.pem")
    ssl_keyfile = settings.ssl_keyfile or str(project_root / "certs" / "localhost-key.pem")

    # Check if SSL certificates exist
    if os.path.exists(ssl_certfile) and os.path.exists(ssl_keyfile):
        logger.info(f"Starting HTTPS server with certificates from {ssl_certfile}")
        uvicorn.run(
            "server.main:app",
            host=settings.host,
            port=settings.port,
            reload=True,
            ssl_certfile=ssl_certfile,
            ssl_keyfile=ssl_keyfile,
        )
    else:
        logger.warning("SSL certificates not found, starting HTTP server (not recommended for production)")
        logger.warning(f"Expected cert at: {ssl_certfile}")
        logger.warning(f"Expected key at: {ssl_keyfile}")
        uvicorn.run(
            "server.main:app",
            host=settings.host,
            port=settings.port,
            reload=True,
        )


if __name__ == "__main__":
    main()
