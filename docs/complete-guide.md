# VibeMobile Complete Guide

> Remote monitoring and control for Claude Code sessions from mobile devices

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Requirements](#2-requirements)
3. [Installation](#3-installation)
4. [Desktop App Usage](#4-desktop-app-usage)
5. [Web UI Usage](#5-web-ui-usage)
6. [Cloudflare Tunnel Setup](#6-cloudflare-tunnel-setup)
7. [Advanced Configuration](#7-advanced-configuration)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. System Overview

### 1.1 What is VibeMobile?

VibeMobile is a remote monitoring and control tool that allows you to:

- **View real-time** Claude Code terminal output
- **Send messages** and commands to Claude remotely
- **Upload images** to Claude Code sessions
- **Send special keys** like Ctrl+C, Escape, etc.

### 1.2 Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Your Mac                                      │
│  ┌─────────────┐    ┌─────────────────────────────────┐            │
│  │  Desktop    │    │      Node.js Server (:8765)     │            │
│  │  (Flutter)  │───▶│  REST API + WebSocket + Static  │            │
│  │             │    └─────────────────────────────────┘            │
│  └─────────────┘                  │                                 │
│         │                         ▼                                 │
│         │                 ┌─────────────┐                          │
│         │                 │ Tmux Sessions│                          │
│         │                 │(claude code) │                          │
│         │                 └─────────────┘                          │
└─────────┼───────────────────────────────────────────────────────────┘
          │
          │      ┌──────────────────────┐
          └─────▶│  Cloudflare Tunnel   │
                 │  (remote access)     │
                 └──────────────────────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │   Mobile Browser     │
                 └──────────────────────┘
```

### 1.3 Components

| Component | Technology | Port | Description |
|-----------|------------|------|-------------|
| **Server** | Node.js + Express | 8765 | REST API + WebSocket + Static files |
| **Web UI** | React + Vite | (bundled) | Mobile-friendly interface |
| **Desktop App** | Flutter (macOS) | - | Local management GUI |
| **Tunnel** | cloudflared | - | Secure remote access |

---

## 2. Requirements

### 2.1 Software Dependencies

| Software | Version | Purpose | Install Command |
|----------|---------|---------|-----------------|
| **Node.js** | 18+ | Server runtime | `brew install node` |
| **tmux** | 3.0+ | Session management | `brew install tmux` |
| **Flutter** | 3.5+ | Desktop app (optional) | [flutter.dev](https://flutter.dev) |
| **cloudflared** | - | Remote access (optional) | `brew install cloudflare/cloudflare/cloudflared` |

### 2.2 Verify Installation

```bash
node --version    # Should show v18+
tmux -V           # Should show tmux 3.x
```

---

## 3. Installation

### 3.1 Clone and Setup

```bash
git clone https://github.com/fafa-npu/VibeMobile.git
cd VibeMobile/web
npm install
```

### 3.2 Start the Server

```bash
# Production mode (serves static files)
npm run build
npm start

# Development mode (hot reload)
npm run dev
```

Server runs at `http://localhost:8765`

### 3.3 Build Desktop App (Optional)

```bash
cd desktop
flutter pub get
flutter build macos --release
```

The app will be at `desktop/build/macos/Build/Products/Release/VibeMobile.app`

### 3.4 Verify Installation

```bash
# Test health check
curl http://localhost:8765/health
# Should return: {"status":"ok",...}
```

---

## 4. Desktop App Usage

### 4.1 Main Features

The Desktop app provides:

- **Service Control**: Start/stop the Node.js server
- **Session Management**: View and create tmux sessions
- **Device Management**: Pair and manage mobile devices
- **Tunnel Control**: Enable/disable Cloudflare Tunnel

### 4.2 Service Status

| Status | Indicator | Description |
|--------|-----------|-------------|
| Running | Green | Service is active |
| Starting | Yellow | Service is starting |
| Stopped | Gray | Service not running |
| Error | Red | Service failed |

### 4.3 Device Pairing

1. Click **"Generate Pairing Code"**
2. A 6-digit code appears (valid for 5 minutes)
3. Enter code on mobile device
4. Approve the pairing request

### 4.4 Trust Levels

| Level | Permissions |
|-------|-------------|
| **Full** | All operations including create/kill sessions |
| **Partial** | Send messages, upload files |
| **View Only** | Read-only access to output |

---

## 5. Web UI Usage

### 5.1 Access Methods

**Local Network:**
```
http://localhost:8765
http://YOUR_MAC_IP:8765
```

**Remote (via Tunnel):**
```
https://your-tunnel-url.trycloudflare.com
```

### 5.2 Device Pairing Flow

1. Open Web UI on mobile
2. Enter the 6-digit pairing code from Desktop app
3. Wait for approval
4. Access granted

### 5.3 Session Interaction

- **View Output**: Real-time terminal output via WebSocket
- **Send Messages**: Type in the input box and send
- **Special Keys**: Toolbar with Ctrl+C, Escape, Enter
- **Upload Images**: Share screenshots or images

### 5.4 Mobile Optimization

- Responsive design for all screen sizes
- Touch-friendly controls
- Auto-scroll to latest output
- PWA support (coming soon)

---

## 6. Cloudflare Tunnel Setup

### 6.1 Quick Tunnel (Temporary)

Simplest way - no configuration needed:

```bash
cloudflared tunnel --url http://localhost:8765
```

This creates a temporary URL like `https://abc123.trycloudflare.com`

**Limitations:**
- URL changes each time
- No custom domain

### 6.2 Named Tunnel (Persistent)

For permanent access with custom domain:

#### Step 1: Login to Cloudflare
```bash
cloudflared login
```

#### Step 2: Create Tunnel
```bash
cloudflared tunnel create VibeMobile
```

#### Step 3: Configure DNS
```bash
cloudflared tunnel route dns VibeMobile your-subdomain.yourdomain.com
```

#### Step 4: Create Config File

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: VibeMobile
credentials-file: /Users/YOUR_USER/.cloudflared/TUNNEL_ID.json

ingress:
  - hostname: your-subdomain.yourdomain.com
    service: http://localhost:8765
  - service: http_status:404
```

#### Step 5: Run Tunnel
```bash
cloudflared tunnel run VibeMobile
```

---

## 7. Advanced Configuration

### 7.1 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST` | `0.0.0.0` | Server bind address |
| `PORT` | `8765` | Server port |
| `TMUX_PREFIX` | `vibe` | Tmux session prefix |
| `TMUX_HISTORY` | `500` | Output lines to capture |

### 7.2 Data Storage

Runtime data stored in `~/.vibemobile/`:
- `devices.json` - Paired device information
- `.secret_key` - JWT signing key (auto-generated)
- `audit.log` - Action audit log

### 7.3 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/api/sessions` | GET | List all sessions |
| `/api/sessions` | POST | Create new session |
| `/api/sessions/{id}` | GET | Get session details |
| `/api/sessions/{id}` | DELETE | Kill session |
| `/api/sessions/{id}/output` | GET | Get session output |
| `/api/sessions/{id}/send` | POST | Send command |
| `/api/sessions/{id}/key` | POST | Send special key |
| `/api/sessions/{id}/upload` | POST | Upload file |
| `/api/sessions/{id}/files` | GET | List files |
| `/api/auth/pair/initiate` | POST | Generate pairing code |
| `/api/auth/pair/complete` | POST | Complete pairing |
| `/api/auth/refresh` | POST | Refresh token |
| `/api/auth/devices` | GET | List devices |
| `/ws` | WebSocket | Real-time updates |

---

## 8. Troubleshooting

### 8.1 Server Issues

**Server won't start:**
```bash
# Check if port is in use
lsof -i :8765

# Kill existing process if needed
kill -9 $(lsof -t -i :8765)

# Verify Node.js version
node --version
```

**Dependencies error:**
```bash
cd web
rm -rf node_modules
npm install
```

### 8.2 Session Issues

**Sessions not appearing:**
```bash
# Check tmux is installed
tmux -V

# List existing sessions
tmux ls

# Sessions must have "vibe-" prefix
tmux new-session -s vibe-test
```

### 8.3 WebSocket Issues

**Real-time updates not working:**
- Check server is running
- Check browser console for errors
- Try refreshing the page
- Re-pair the device if token expired

### 8.4 Tunnel Issues

**Tunnel won't connect:**
```bash
# Check cloudflared is installed
cloudflared --version

# Test network connectivity
curl -I https://cloudflare.com

# If behind proxy
export HTTPS_PROXY=http://127.0.0.1:7890
```

### 8.5 Reset Everything

```bash
# Stop all services
pkill -f "node.*server"
pkill cloudflared

# Remove settings
rm -rf ~/.vibemobile/

# Restart
cd web && npm start
```

---

## Quick Reference

### Commands

```bash
# Start server
cd web && npm start

# Development mode
cd web && npm run dev

# Quick tunnel
cloudflared tunnel --url http://localhost:8765

# List tmux sessions
tmux ls

# Create session
tmux new-session -s vibe-myproject -c ~/myproject

# Attach to session
tmux attach -t vibe-myproject
```

### Ports

| Service | Port | Protocol |
|---------|------|----------|
| Server | 8765 | HTTP/WS |

---

*Document Version: 2.0*
*Last Updated: 2025-12-30*
