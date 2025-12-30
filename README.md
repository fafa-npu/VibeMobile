# VibeMobile

Remote monitoring and control for Claude Code sessions from your mobile device.

VibeMobile allows you to monitor and interact with your Claude Code terminal sessions remotely through a web interface, accessible from your phone or tablet.

## Features

- **Real-time Session Monitoring**: View Claude Code output in real-time via WebSocket streaming
- **Remote Input**: Send messages and commands to Claude Code sessions from your mobile device
- **Special Key Support**: Send Ctrl+C, Ctrl+D, Escape, and other special keys
- **File Browser**: Browse and preview files in your session directories
- **Image Upload**: Upload images directly to Claude Code sessions
- **Secure Device Pairing**: Pair mobile devices using a 6-digit code with Desktop approval
- **Trust Levels**: Control device permissions (Full, Partial, View-Only)
- **Cloudflare Tunnel**: Expose your local server securely for remote access

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Desktop App    │     │   Node.js Server │     │    Web UI       │
│   (Flutter)     │────▶│   (Express/WS)   │◀────│    (React)      │
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
| Server | Node.js Express | 8765 | REST API + WebSocket backend |
| Web UI | React + Vite | 5173 (dev) | Mobile-friendly web interface |
| Desktop | Flutter (macOS) | - | Local management application |

## Quick Start

### Prerequisites

- **Node.js 18+** with npm
- **Flutter 3.5+** (for Desktop app)
- **tmux** (for session management)
- **cloudflared** (optional, for remote access)

### 1. Clone and Setup

```bash
git clone https://github.com/yourusername/VibeMobile.git
cd VibeMobile
```

### 2. Start the Server

```bash
cd web
npm install
npm run build
npm start
```

The server runs at `http://localhost:8765` and serves both API and static web files.

### 3. Development Mode

For development with hot-reload:

```bash
cd web
npm run dev
```

This starts both the API server and Vite dev server.

### 4. Build and Run Desktop App (Optional)

```bash
cd desktop
flutter pub get
flutter run -d macos
```

The Desktop app provides a GUI for managing services and devices.

## Usage Guide

### Desktop Application

The Desktop app is your control center for VibeMobile:

1. **Start Server**: Launch the Node.js backend server
2. **View Sessions**: See all active Claude Code sessions
3. **Create Sessions**: Start a new Claude Code session in tmux
4. **Device Management**: Pair and manage mobile devices
5. **Cloudflare Tunnel**: Enable remote access via tunnel

### Mobile Web Interface

Access the Web UI from your mobile device:

#### Local Access
Open `http://localhost:8765` (same network required)

#### Remote Access (via Cloudflare Tunnel)
1. Install cloudflared: `brew install cloudflare/cloudflare/cloudflared`
2. Start tunnel: `cloudflared tunnel --url http://localhost:8765`
3. Copy the generated public URL
4. Open the URL on your mobile device

#### First-Time Setup (Pairing)

1. Open Web UI on your mobile browser
2. In Desktop app, go to "Devices" → "Generate Pairing Code"
3. Enter the 6-digit code in the Web UI
4. Approve the pairing request in Desktop app

#### Session Interaction

- **View Output**: See Claude Code terminal output in real-time
- **Send Messages**: Type and send messages to Claude
- **Special Keys**: Use the toolbar for Ctrl+C, Escape, etc.
- **Browse Files**: View files in the session working directory
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
| `/api/sessions/{id}/files` | GET | List files in session |
| `/api/sessions/{id}/files/{path}` | GET | Get file content |
| `/api/auth/pair/initiate` | POST | Generate pairing code |
| `/api/auth/pair/complete` | POST | Complete pairing |
| `/api/auth/refresh` | POST | Refresh access token |
| `/api/auth/devices` | GET | List paired devices |
| `/health` | GET | Health check |

### WebSocket

Connect to `/ws` for real-time updates:

```javascript
const ws = new WebSocket('ws://localhost:8765/ws');

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
| `HOST` | `0.0.0.0` | Server bind address |
| `PORT` | `8765` | Server port |
| `SSL_CERT` | - | SSL certificate path (optional) |
| `SSL_KEY` | - | SSL key path (optional) |
| `TMUX_PREFIX` | `vibe` | Tmux session name prefix |
| `TMUX_HISTORY` | `500` | Lines of output to capture |

### Data Storage

Runtime data is stored in `~/.vibemobile/`:
- `devices.json` - Paired device information
- `.secret_key` - JWT signing key (auto-generated)
- `audit.log` - Action audit log

## Project Structure

```
VibeMobile/
├── web/                    # Node.js server + React frontend
│   ├── server/            # Express backend
│   │   ├── routes/        # API routes
│   │   ├── services/      # Business logic
│   │   ├── middleware/    # Auth middleware
│   │   └── index.ts       # Entry point
│   ├── src/               # React frontend
│   │   ├── components/    # UI components
│   │   ├── pages/         # Page components
│   │   ├── services/      # API clients
│   │   ├── stores/        # Zustand stores
│   │   └── hooks/         # React hooks
│   └── vite.config.ts     # Vite configuration
├── desktop/                # Flutter desktop app
│   └── lib/
│       ├── core/          # Core utilities
│       ├── data/          # Data models
│       ├── domain/        # Domain services
│       └── presentation/  # UI layer
├── scripts/               # Installation scripts
└── docs/                  # Documentation
```

## Security Considerations

1. **Local-First**: Server runs locally, no cloud dependency
2. **Cloudflare Tunnel**: Secure remote access without exposing ports
3. **Device Pairing**: Mobile devices must be paired via 6-digit code + Desktop approval
4. **Token-based Auth**: Short-lived access tokens with secure refresh tokens
5. **Trust Levels**: Granular permission control per device
6. **Audit Logging**: All actions are logged with device and IP information

## Troubleshooting

### Server Won't Start

1. Check if port 8765 is in use: `lsof -i :8765`
2. Ensure Node.js 18+ is installed: `node --version`
3. Run `npm install` in the web directory

### Sessions Not Appearing

1. Verify tmux is installed: `tmux -V`
2. Check session prefix matches (default: `vibe`)
3. List tmux sessions: `tmux ls`

### WebSocket Connection Failed

1. Check that server is running
2. Verify connecting to correct port
3. Check browser console for errors

### Cloudflare Tunnel Issues

1. Install cloudflared: `brew install cloudflare/cloudflare/cloudflared`
2. Ensure no proxy interfering with connection
3. Check cloudflared logs for errors

## Development

### Run Tests

```bash
# TypeScript checks
cd web
npm run lint

# Flutter tests
cd desktop
flutter test
```

### Build for Production

```bash
# Build web server + frontend
cd web
npm run build

# Build desktop app
cd desktop
flutter build macos --release
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and linting
5. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.
