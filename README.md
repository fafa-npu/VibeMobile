# VibeMobile

Remote control for Claude Code sessions from your phone.

## Quick Start (3 Steps)

```bash
# 1. Clone and install
git clone https://github.com/yourusername/VibeMobile.git
cd VibeMobile/web && npm install

# 2. Start the server
npm start

# 3. Open in browser
# Local: http://localhost:8765
# Remote: Use Cloudflare Tunnel (see below)
```

That's it! Your Claude Code sessions (running in tmux with `vibe-` prefix) will appear automatically.

---

## What is VibeMobile?

VibeMobile lets you monitor and interact with Claude Code terminal sessions from your mobile device:

- **Real-time output** - See Claude's responses as they happen
- **Send messages** - Type and send to Claude from your phone
- **Special keys** - Send Ctrl+C, Escape, Enter
- **File browser** - Browse files in your session directory
- **Image upload** - Share screenshots with Claude
- **Secure pairing** - 6-digit code + Desktop approval

## Requirements

- **Node.js 18+** - `brew install node`
- **tmux** - `brew install tmux`
- **cloudflared** (optional) - `brew install cloudflare/cloudflare/cloudflared`

## Usage

### Start a Claude Code Session

```bash
# Create a tmux session with vibe- prefix
tmux new-session -s vibe-myproject -c ~/myproject

# Start Claude Code inside
claude
```

### Access from Mobile

**Same Network:**
Open `http://YOUR_MAC_IP:8765` on your phone.

**Remote Access (Cloudflare Tunnel):**
```bash
cloudflared tunnel --url http://localhost:8765
# Opens a public URL like https://abc123.trycloudflare.com
```

### Desktop App (Optional)

The Flutter desktop app provides a GUI for managing services:

```bash
cd desktop
flutter pub get
flutter run -d macos
```

## Device Pairing

Remote devices must be paired for security:

1. Open Web UI on your phone
2. Generate pairing code in Desktop app (or via API)
3. Enter 6-digit code on phone
4. Approve on Desktop

Trust levels: **Full** (all operations) | **Partial** (send messages) | **View Only** (read-only)

## API Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/sessions` | GET | List sessions |
| `/api/sessions/{id}/output` | GET | Get output |
| `/api/sessions/{id}/send` | POST | Send message |
| `/api/sessions/{id}/key` | POST | Send special key |
| `/api/sessions/{id}/upload` | POST | Upload file |
| `/ws` | WebSocket | Real-time updates |

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8765` | Server port |
| `HOST` | `0.0.0.0` | Bind address |
| `TMUX_PREFIX` | `vibe` | Session prefix |

Data stored in `~/.vibemobile/` (devices, JWT key, audit log).

## Development

```bash
cd web
npm run dev     # Start with hot-reload
npm run lint    # Check code style
npm run build   # Production build
```

## Project Structure

```
VibeMobile/
├── web/                # Server + Web UI
│   ├── server/         # Node.js Express backend
│   └── src/            # React frontend
├── desktop/            # Flutter macOS app
├── docs/               # Additional documentation
└── scripts/            # Install scripts
```

## Troubleshooting

**Sessions not appearing?**
- Ensure tmux sessions start with `vibe-` prefix
- Check: `tmux ls`

**Can't connect?**
- Verify server is running: `curl http://localhost:8765/health`
- Check port isn't blocked: `lsof -i :8765`

## License

MIT License - see [LICENSE](LICENSE)
