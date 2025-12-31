#!/bin/bash
# VibeMobile Desktop App Health Check Script
# Usage: ./health_check.sh

echo "=== VibeMobile Health Check ==="

# Check if app is running
if pgrep -f "VibeMobile.app" > /dev/null; then
    echo "✅ Desktop app is running"
else
    echo "❌ Desktop app is NOT running"
fi

# Check API Server
if curl -s http://localhost:8765/health | grep -q "healthy"; then
    echo "✅ API Server is healthy (port 8765)"
else
    echo "❌ API Server is NOT responding"
fi

# Check Web UI
if curl -s -o /dev/null -w "%{http_code}" http://localhost:5173/ | grep -q "200"; then
    echo "✅ Web UI is running (port 5173)"
else
    echo "❌ Web UI is NOT responding"
fi

# Check for blocking processes
FROZEN=$(ps aux | grep -E "(flutter|dart)" | grep -v grep | awk '$9 ~ /[0-9]+:[0-9]+/ && $3 > 90 {print $0}')
if [ -n "$FROZEN" ]; then
    echo "⚠️  Potentially frozen processes detected:"
    echo "$FROZEN"
else
    echo "✅ No frozen processes detected"
fi

echo "=== Check Complete ==="
