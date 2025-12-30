# VibeMobile

Remote control for Claude Code sessions from your phone.

## Installation

### Download (Recommended)

1. Download `VibeMobile.dmg` from [Releases](https://github.com/fafa-npu/VibeMobile/releases)
2. Open DMG and drag VibeMobile to Applications
3. Run VibeMobile

**That's it!** The server is bundled inside the app.

### Build from Source

```bash
git clone https://github.com/fafa-npu/VibeMobile.git
cd VibeMobile

# Build server
cd web && npm install && npm run build && cd ..

# Build app
cd desktop && flutter pub get && flutter build macos --release
```

---

## Usage

### 1. Start App

Run **VibeMobile.app** - this is your control center.

### 2. Start Server

Click **"Start Server"**. Server runs at `http://localhost:8765`

### 3. Create Session

Click **"New Session"** → Select folder → Claude Code starts automatically.

### 4. Connect from Phone

**Same network:** `http://YOUR_MAC_IP:8765`

**Remote:** Click **"Start Tunnel"** in the app → Copy the generated URL

### 5. Pair Device

1. **App**: Devices → "Generate Pairing Code"
2. **Phone**: Enter 6-digit code
3. **App**: Approve request
4. Done!

---

## Features

- Real-time output streaming
- Send messages to Claude
- Special keys (Ctrl+C, Escape)
- File browser
- Image upload
- Secure device pairing

## Requirements

| Software | Install |
|----------|---------|
| Node.js 18+ | `brew install node` |
| tmux | `brew install tmux` |
| cloudflared | `brew install cloudflare/cloudflare/cloudflared` |

## Trust Levels

| Level | Permissions |
|-------|-------------|
| Full | All operations |
| Partial | Send messages, upload |
| View Only | Read-only |

## Troubleshooting

**Server won't start?** → Ensure Node.js is installed: `node --version`

**No sessions?** → Check tmux: `tmux ls`

**Pairing failed?** → Code expires in 5 minutes, approve in app

## Development

```bash
cd web && npm run dev   # Dev server with hot-reload
cd web && npm run build # Production build
```

## License

MIT - see [LICENSE](LICENSE)
