#!/bin/bash
#
# VibeMobile Task Completion Notification Hook
#
# This script is called by Claude Code's Stop hook when a task completes.
# It sends a notification to the VibeMobile server, which broadcasts it
# to all connected clients via WebSocket.
#
# Configuration:
#   VIBE_SERVER_URL - VibeMobile server URL (default: https://localhost:8765)
#   VIBE_NOTIFICATION_ENABLED - Set to "false" to disable notifications
#
# Usage:
#   This script is invoked automatically by Claude Code hooks.
#   See settings.json for configuration.
#

# Configuration with defaults
VIBE_SERVER_URL="${VIBE_SERVER_URL:-https://localhost:8765}"
VIBE_NOTIFICATION_ENABLED="${VIBE_NOTIFICATION_ENABLED:-true}"

# Exit early if notifications are disabled
if [ "$VIBE_NOTIFICATION_ENABLED" = "false" ]; then
    exit 0
fi

# Notification endpoint
NOTIFICATION_URL="${VIBE_SERVER_URL}/api/notifications"

# Send notification
# -k: Allow insecure SSL (for local self-signed certificates)
# -s: Silent mode (no progress output)
# -o /dev/null: Discard response body
# -w '%{http_code}': Output HTTP status code
HTTP_STATUS=$(curl -k -s -o /dev/null -w '%{http_code}' \
    -X POST "${NOTIFICATION_URL}" \
    -H "Content-Type: application/json" \
    -d '{
        "type": "task_complete",
        "message": "Claude 任务已完成",
        "priority": "high",
        "sound": true
    }' \
    --connect-timeout 5 \
    --max-time 10 \
    2>/dev/null)

# Log result (optional, for debugging)
if [ "$HTTP_STATUS" = "200" ]; then
    echo "[VibeMobile] Notification sent successfully" >&2
else
    echo "[VibeMobile] Failed to send notification (HTTP $HTTP_STATUS)" >&2
fi

exit 0
