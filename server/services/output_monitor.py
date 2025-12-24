"""Output monitoring service for tmux sessions."""

import asyncio
from datetime import datetime
from typing import Callable, Awaitable, Optional
import difflib
import logging

from ..config import settings
from ..models import SessionOutput
from .tmux_manager import tmux_manager

logger = logging.getLogger(__name__)


class OutputMonitor:
    """Monitors tmux sessions for output changes and broadcasts updates."""

    def __init__(self):
        self.interval = settings.monitor_interval
        self._running = False
        self._tasks: dict[str, asyncio.Task] = {}
        self._last_outputs: dict[str, str] = {}
        self._subscribers: list[Callable[[SessionOutput], Awaitable[None]]] = []

    def subscribe(self, callback: Callable[[SessionOutput], Awaitable[None]]) -> None:
        """Subscribe to output updates."""
        self._subscribers.append(callback)

    def unsubscribe(self, callback: Callable[[SessionOutput], Awaitable[None]]) -> None:
        """Unsubscribe from output updates."""
        if callback in self._subscribers:
            self._subscribers.remove(callback)

    async def _broadcast(self, output: SessionOutput) -> None:
        """Broadcast output to all subscribers."""
        for callback in self._subscribers:
            try:
                await callback(output)
            except Exception as e:
                logger.error(f"Error broadcasting to subscriber: {e}")

    def _compute_diff(self, old: str, new: str) -> Optional[str]:
        """Compute the new content that was added."""
        if not old:
            return new

        old_lines = old.splitlines(keepends=True)
        new_lines = new.splitlines(keepends=True)

        # Find the point where content diverges
        # tmux output can shift, so we look for the best match
        if len(new_lines) <= len(old_lines):
            # Screen was likely cleared or scrolled
            return new

        # Simple approach: find new lines at the end
        # This works well for terminal output that appends
        common_prefix_len = 0
        for i, (o, n) in enumerate(zip(old_lines, new_lines)):
            if o == n:
                common_prefix_len = i + 1
            else:
                break

        if common_prefix_len < len(new_lines):
            new_content = "".join(new_lines[common_prefix_len:])
            return new_content

        return None

    async def _monitor_session(self, session_id: str) -> None:
        """Monitor a single session for output changes."""
        logger.info(f"Starting monitor for session: {session_id}")

        while self._running and tmux_manager.session_exists(session_id):
            try:
                current_output = tmux_manager.capture_output(session_id)

                if current_output is None:
                    # Session might have ended
                    await asyncio.sleep(self.interval)
                    continue

                last_output = self._last_outputs.get(session_id, "")

                if current_output != last_output:
                    # Compute diff
                    diff = self._compute_diff(last_output, current_output)

                    if diff:
                        output = SessionOutput(
                            session_id=session_id,
                            content=diff,
                            timestamp=datetime.now(),
                            is_diff=True,
                        )
                        await self._broadcast(output)

                    self._last_outputs[session_id] = current_output

                await asyncio.sleep(self.interval)

            except asyncio.CancelledError:
                logger.info(f"Monitor cancelled for session: {session_id}")
                break
            except Exception as e:
                logger.error(f"Error monitoring session {session_id}: {e}")
                await asyncio.sleep(self.interval)

        logger.info(f"Monitor stopped for session: {session_id}")

        # Clean up
        if session_id in self._last_outputs:
            del self._last_outputs[session_id]

    async def start_monitoring(self, session_id: str) -> None:
        """Start monitoring a specific session."""
        if session_id in self._tasks and not self._tasks[session_id].done():
            return  # Already monitoring

        self._running = True
        task = asyncio.create_task(self._monitor_session(session_id))
        self._tasks[session_id] = task

    async def stop_monitoring(self, session_id: str) -> None:
        """Stop monitoring a specific session."""
        if session_id in self._tasks:
            task = self._tasks[session_id]
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass
            del self._tasks[session_id]

    async def start_all(self) -> None:
        """Start monitoring all existing vibe sessions."""
        self._running = True
        sessions = tmux_manager.list_sessions()
        for session in sessions:
            await self.start_monitoring(session.session_id)

    async def stop_all(self) -> None:
        """Stop all monitoring tasks."""
        self._running = False
        for session_id in list(self._tasks.keys()):
            await self.stop_monitoring(session_id)

    async def refresh_sessions(self) -> None:
        """Refresh the list of monitored sessions."""
        sessions = tmux_manager.list_sessions()
        current_session_ids = {s.session_id for s in sessions}
        monitored_ids = set(self._tasks.keys())

        # Start monitoring new sessions
        for session_id in current_session_ids - monitored_ids:
            await self.start_monitoring(session_id)

        # Stop monitoring ended sessions
        for session_id in monitored_ids - current_session_ids:
            await self.stop_monitoring(session_id)

    def get_full_output(self, session_id: str) -> Optional[str]:
        """Get the full captured output for a session."""
        return self._last_outputs.get(session_id) or tmux_manager.capture_output(
            session_id
        )


# Singleton instance
output_monitor = OutputMonitor()
