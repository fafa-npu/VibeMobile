"""VibeMobile Server - Main entry point."""

import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

from .config import settings
from .api import sessions_router, websocket_router
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

    logger.info(f"Server running on http://{settings.host}:{settings.port}")
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
    uvicorn.run(
        "server.main:app",
        host=settings.host,
        port=settings.port,
        reload=True,
    )


if __name__ == "__main__":
    main()
