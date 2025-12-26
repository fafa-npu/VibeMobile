# VibeMobile

Remote monitoring and control for Claude Code sessions from your mobile device.

VibeMobile allows you to monitor and interact with your Claude Code terminal sessions remotely through a web interface, accessible from your phone or tablet.

## Features

- **Real-time Session Monitoring**: View Claude Code output in real-time via WebSocket streaming
- **Remote Input**: Send messages and commands to Claude Code sessions from your mobile device
- **Special Key Support**: Send Ctrl+C, Ctrl+D, Escape, and other special keys
- **Image Upload**: Upload images directly to Claude Code sessions
- **Secure Device Pairing**: Pair mobile devices using a 6-digit code with Desktop approval
- **Trust Levels**: Control device permissions (Full, Partial, View-Only)
- **Cloudflare Tunnel**: Expose your local server securely for remote access
- **HTTPS by Default**: Local development uses mkcert-generated certificates

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Desktop App    │     │   API Server     │     │    Web UI       │
│   (Flutter)     │────▶│    (FastAPI)     │◀────│    (React)      │
│                 │     │                  │     │                 │
│ - Start/Stop    │     │ - REST API       │     │ - Session List  │
│ - Device Mgmt   │     │ - WebSocket      │     │ - Real-time     │
│ - Tunnel        │     │ - Tmux Control   │     │ - Input/Upload  │
└─────────────────┘     └──────────────────┘     └─────────────────┘
         │                       │                        │
         │                       ▼                        │
         │              ┌──────────────────┐              │
         │              │   Tmux Sessions  │              │
         │              │   (claude code)  │              │
         │              └──────────────────┘              │
         │                                                │
         └──────────────── Cloudflare Tunnel ─────────────┘
```

## Components

| Component | Technology | Port | Description |
|-----------|------------|------|-------------|
| Server | Python FastAPI | 8765 | REST API + WebSocket backend |
| Web UI | React + Vite | 5173 | Mobile-friendly web interface |
| Desktop | Flutter (macOS) | - | Local management application |

## Quick Start

### Prerequisites

- **Python 3.11+** with uv (recommended) or pip
- **Node.js 18+** with npm
- **Flutter 3.5+** (for Desktop app)
- **tmux** (for session management)
- **mkcert** (for local HTTPS certificates)
- **cloudflared** (optional, for remote access)

### 1. Clone and Setup

```bash
git clone https://github.com/your-repo/VibeMobile.git
cd VibeMobile
```

### 2. Generate SSL Certificates

```bash
# Install mkcert (macOS)
brew install mkcert
mkcert -install

# Generate certificates
mkdir -p certs
mkcert -key-file certs/localhost-key.pem -cert-file certs/localhost.pem localhost 127.0.0.1
```

### 3. Start the API Server

```bash
# Using uv (recommended)
uv sync
uv run python -m server.main

# Or using pip
pip install -e .
vibe-server
```

The API server runs at `https://localhost:8765`

### 4. Start the Web UI

```bash
cd web
npm install
npm run dev
```

The Web UI runs at `https://localhost:5173`

### 5. Build and Run Desktop App

```bash
cd desktop
flutter pub get
flutter run -d macos
```

## Usage Guide

### Desktop Application

The Desktop app is your control center for VibeMobile:

1. **Start All Services**: Click "Start All" to launch both API Server and Web UI
2. **View Sessions**: See all active Claude Code sessions
3. **Create Sessions**: Click + to start a new Claude Code session
4. **Device Management**: Pair and manage mobile devices
5. **Cloudflare Tunnel**: Enable remote access via tunnel

#### Starting Services

- **Start API**: Launches the FastAPI backend server
- **Start Web**: Starts the Vite development server for Web UI
- **Start Tunnel**: Creates a Cloudflare tunnel for remote access
- **Start All**: Launches API and Web together

### Mobile Web Interface

Access the Web UI from your mobile device:

#### Local Access
Open `https://localhost:5173` (same network required)

#### Remote Access (via Cloudflare Tunnel)
1. Click "Start Tunnel" in Desktop app
2. Copy the generated public URL
3. Open the URL on your mobile device

#### First-Time Setup (Pairing)

1. Open Web UI on your mobile browser
2. In Desktop app, go to "Devices" → "Generate Pairing Code"
3. Enter the 6-digit code in the Web UI
4. Approve the pairing request in Desktop app

#### Session Interaction

- **View Output**: See Claude Code terminal output in real-time
- **Send Messages**: Type and send messages to Claude
- **Special Keys**: Use the toolbar for Ctrl+C, Escape, etc.
- **Upload Images**: Send screenshots or images to Claude

### Trust Levels

| Level | Permissions |
|-------|-------------|
| **Full** | All operations including session create/kill |
| **Partial** | Send messages, upload files |
| **View Only** | Read-only access to session output |

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/sessions` | GET | List all sessions |
| `/api/sessions/{id}` | GET | Get session details |
| `/api/sessions/{id}/output` | GET | Get session output |
| `/api/sessions/{id}/send` | POST | Send command to session |
| `/api/sessions/{id}/key` | POST | Send special key |
| `/api/sessions/{id}/upload` | POST | Upload file |
| `/api/sessions` | POST | Create new session |
| `/api/sessions/{id}` | DELETE | Kill session |
| `/api/auth/pair/initiate` | POST | Generate pairing code |
| `/api/auth/pair/complete` | POST | Complete pairing |
| `/api/auth/refresh` | POST | Refresh access token |
| `/api/auth/devices` | GET | List paired devices |
| `/health` | GET | Health check |

### WebSocket

Connect to `/ws` for real-time updates:

```javascript
const ws = new WebSocket('wss://localhost:8765/ws?token=YOUR_ACCESS_TOKEN');

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  // Handle session output updates
};

// Subscribe to sessions
ws.send(JSON.stringify({
  type: 'subscribe',
  sessionIds: ['session1', 'session2']
}));
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VIBE_HOST` | `0.0.0.0` | Server bind address |
| `VIBE_PORT` | `8765` | Server port |
| `VIBE_SSL_CERTFILE` | `certs/localhost.pem` | SSL certificate path |
| `VIBE_SSL_KEYFILE` | `certs/localhost-key.pem` | SSL key path |

### Desktop Settings

Settings are stored in `~/.vibemobile/settings.json`:

```json
{
  "apiPort": 8765,
  "webPort": 5173,
  "sessionPrefix": "vibe",
  "autoStartServer": false,
  "tunnelProxy": "http://127.0.0.1:7890"
}
```

## Project Structure

```
VibeMobile/
├── server/                 # Python FastAPI backend
│   ├── api/               # API routes
│   │   ├── sessions.py    # Session management
│   │   ├── auth.py        # Device authentication
│   │   └── websocket.py   # WebSocket handler
│   ├── services/          # Business logic
│   │   ├── tmux_manager.py
│   │   ├── auth_service.py
│   │   └── ws_manager.py
│   ├── models/            # Data models
│   └── main.py            # Entry point
├── web/                    # React frontend
│   ├── src/
│   │   ├── components/    # UI components
│   │   ├── pages/         # Page components
│   │   ├── services/      # API clients
│   │   ├── stores/        # Zustand stores
│   │   └── hooks/         # React hooks
│   └── vite.config.ts     # Vite configuration
├── desktop/                # Flutter desktop app
│   └── lib/
│       ├── core/          # Core utilities
│       ├── data/          # Data layer
│       ├── domain/        # Domain services
│       └── presentation/  # UI layer
├── certs/                  # SSL certificates
└── pyproject.toml         # Python project config
```

## Security Considerations

1. **HTTPS Required**: All connections use HTTPS/WSS with self-signed certificates
2. **Device Pairing**: Mobile devices must be paired via 6-digit code + Desktop approval
3. **Token-based Auth**: Short-lived access tokens with secure refresh tokens
4. **Trust Levels**: Granular permission control per device
5. **Local-only Management**: Device management only accessible from localhost
6. **Audit Logging**: All actions are logged with device and IP information

## Troubleshooting

### Certificate Errors

If you see SSL/certificate errors:

```bash
# Regenerate certificates
cd certs
mkcert -key-file localhost-key.pem -cert-file localhost.pem localhost 127.0.0.1

# Trust the root CA
mkcert -install
```

### Cloudflare Tunnel Not Working

1. Check if cloudflared is installed: `cloudflared --version`
2. Ensure proxy settings if behind a firewall
3. Verify the tunnel is forwarding to Web UI port (5173), not API port

### WebSocket Connection Failed

1. Check that API server is running
2. Verify HTTPS certificates are valid
3. Ensure the browser trusts the self-signed certificate

### Sessions Not Appearing

1. Verify tmux is installed: `tmux -V`
2. Check session prefix matches (default: `vibe`)
3. Ensure API server can access tmux sessions

## Development

### Run Tests

```bash
# Python tests
cd server
pytest

# TypeScript checks
cd web
npm run lint
```

### Build for Production

```bash
# Build web UI
cd web
npm run build

# Build desktop app
cd desktop
flutter build macos --release
```

## License

MIT License

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.
