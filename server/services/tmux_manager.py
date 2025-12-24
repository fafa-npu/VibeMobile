"""tmux session management service."""

import subprocess
import re
from typing import Optional
from datetime import datetime

from ..config import settings
from ..models import Session


class TmuxManager:
    """Manages tmux sessions for VibeMobile."""

    def __init__(self):
        self.prefix = settings.tmux_session_prefix
        self.capture_history = settings.tmux_capture_history

    def _run_tmux(self, args: list[str]) -> tuple[bool, str]:
        """Run a tmux command and return (success, output)."""
        try:
            result = subprocess.run(
                ["tmux"] + args, capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                return True, result.stdout
            return False, result.stderr
        except subprocess.TimeoutExpired:
            return False, "Command timed out"
        except FileNotFoundError:
            return False, "tmux not found. Please install tmux."
        except Exception as e:
            return False, str(e)

    def _is_claude_running(self, session_id: str) -> bool:
        """Check if claude process is running in the session."""
        # Get the pane PID
        success, pane_pid = self._run_tmux(
            ["display-message", "-t", session_id, "-p", "#{pane_pid}"]
        )
        if not success or not pane_pid.strip():
            return False

        pid = pane_pid.strip()

        # Check if the process or any child is 'claude'
        try:
            # Check direct process
            result = subprocess.run(
                ["ps", "-p", pid, "-o", "command="],
                capture_output=True, text=True, timeout=2
            )
            if "claude" in result.stdout.lower():
                return True

            # Check child processes
            result = subprocess.run(
                ["pgrep", "-P", pid],
                capture_output=True, text=True, timeout=2
            )
            child_pids = result.stdout.strip().split("\n")
            for child_pid in child_pids:
                if child_pid:
                    child_result = subprocess.run(
                        ["ps", "-p", child_pid, "-o", "command="],
                        capture_output=True, text=True, timeout=2
                    )
                    if "claude" in child_result.stdout.lower():
                        return True
        except Exception:
            pass

        return False

    def list_sessions(self) -> list[Session]:
        """List all vibe sessions."""
        success, output = self._run_tmux(
            ["list-sessions", "-F", "#{session_name}:#{session_created}:#{session_attached}"]
        )

        if not success:
            return []

        sessions = []
        for line in output.strip().split("\n"):
            if not line:
                continue

            parts = line.split(":")
            if len(parts) >= 3:
                name, created_ts, attached = parts[0], parts[1], parts[2]

                # Only include sessions with our prefix
                if not name.startswith(self.prefix):
                    continue

                # Convert timestamp
                try:
                    created_at = datetime.fromtimestamp(int(created_ts))
                except (ValueError, TypeError):
                    created_at = datetime.now()

                # Determine status based on whether claude is running
                claude_running = self._is_claude_running(name)
                if claude_running:
                    status = "active"
                else:
                    status = "ended"

                # Get working directory
                _, pane_path = self._run_tmux(
                    ["display-message", "-t", name, "-p", "#{pane_current_path}"]
                )

                # Get recent output
                output_tail = self.capture_output(name) or ""

                sessions.append(
                    Session(
                        session_id=name,
                        project_path=pane_path.strip() if pane_path else "",
                        status=status,
                        created_at=created_at,
                        updated_at=datetime.now(),
                        output_tail=output_tail[-1000:] if output_tail else "",  # Last 1000 chars
                    )
                )

        return sessions

    def get_session(self, session_id: str) -> Optional[Session]:
        """Get a specific session by ID."""
        sessions = self.list_sessions()
        for session in sessions:
            if session.session_id == session_id:
                return session
        return None

    def session_exists(self, session_id: str) -> bool:
        """Check if a session exists."""
        success, output = self._run_tmux(["has-session", "-t", session_id])
        return success

    def capture_output(self, session_id: str, with_ansi: bool = False) -> Optional[str]:
        """Capture the output of a session."""
        args = ["capture-pane", "-t", session_id, "-p", "-S", f"-{self.capture_history}"]
        if with_ansi:
            args.append("-e")

        success, output = self._run_tmux(args)
        if success:
            return output
        return None

    def send_keys(self, session_id: str, text: str, press_enter: bool = True) -> bool:
        """Send keys to a session."""
        if not self.session_exists(session_id):
            return False

        # Send the text
        success, _ = self._run_tmux(["send-keys", "-t", session_id, text])
        if not success:
            return False

        # Press enter if requested
        if press_enter:
            success, _ = self._run_tmux(["send-keys", "-t", session_id, "Enter"])

        return success

    def send_special_key(self, session_id: str, key: str) -> bool:
        """Send a special key (e.g., 'C-c' for Ctrl+C)."""
        if not self.session_exists(session_id):
            return False

        success, _ = self._run_tmux(["send-keys", "-t", session_id, key])
        return success

    def create_session(
        self, command: str = "claude", session_name: Optional[str] = None
    ) -> Optional[str]:
        """Create a new tmux session with Claude."""
        if session_name is None:
            # Generate a unique session name
            existing = self.list_sessions()
            existing_names = {s.session_id for s in existing}
            counter = 1
            while f"{self.prefix}-{counter}" in existing_names:
                counter += 1
            session_name = f"{self.prefix}-{counter}"

        success, _ = self._run_tmux(
            ["new-session", "-d", "-s", session_name, command]
        )

        if success:
            return session_name
        return None

    def kill_session(self, session_id: str) -> bool:
        """Kill a session."""
        success, _ = self._run_tmux(["kill-session", "-t", session_id])
        return success

    def get_next_session_name(self) -> str:
        """Get the next available session name."""
        existing = self.list_sessions()
        existing_nums = []

        for session in existing:
            match = re.match(rf"^{self.prefix}-(\d+)$", session.session_id)
            if match:
                existing_nums.append(int(match.group(1)))

        next_num = max(existing_nums, default=0) + 1
        return f"{self.prefix}-{next_num}"


# Singleton instance
tmux_manager = TmuxManager()
