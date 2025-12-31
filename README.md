# VibeMobile

Remote control for Claude Code sessions from your phone. **macOS only**.

<p align="center">
  <img src="docs/pictures/desktop-main.png" width="600" alt="Desktop App">
</p>

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/fafa-npu/VibeMobile/main/install.sh | bash
```

This installs dependencies and the app. After installation, restart Terminal or run `source ~/.zshrc`.

## Usage

### 1. Start the App

In Terminal, run:
```bash
vibemobile
```

### 2. Start Server & Create Session

Click **"Start Server"**, then click **"+"** to create a new Claude Code session.

<p align="center">
  <img src="docs/pictures/desktop-main.png" width="500" alt="Start Server">
</p>

### 3. Connect from Phone

- **Same network**: Open `http://YOUR_MAC_IP:8765` in your phone browser
- **Remote access**: Click **"Start Tunnel"** and copy the generated URL

<p align="center">
  <img src="docs/pictures/desktop-tunnel.png" width="500" alt="Tunnel URL">
</p>

### 4. Pair Your Device

1. In the desktop app, click **Devices** icon → **"Generate Pairing Code"**
2. On your phone, enter the 6-digit code
3. Approve the pairing request in the desktop app

<p align="center">
  <img src="docs/pictures/desktop-devices.png" width="400" alt="Generate Pairing Code">
  <img src="docs/pictures/mobile-pairing.png" width="200" alt="Enter Code on Phone">
</p>

### 5. Control Claude Code

Once paired, you can:
- View sessions and real-time output
- Send messages to Claude
- Browse project files
- Upload images

<p align="center">
  <img src="docs/pictures/mobile-sessions.png" width="200" alt="Session List">
  <img src="docs/pictures/mobile-terminal.png" width="200" alt="Terminal View">
  <img src="docs/pictures/mobile-files.png" width="200" alt="File Browser">
</p>

## Custom Domain (Optional)

The built-in tunnel generates a random URL each time. For a permanent domain:

1. Set up a [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) with your own domain
2. Point the tunnel to `http://localhost:8765`
3. Access VibeMobile from your custom domain anywhere

## Manual Install

Download `VibeMobile.dmg` from [Releases](https://github.com/fafa-npu/VibeMobile/releases), then:
```bash
xattr -cr /Applications/VibeMobile.app && open /Applications/VibeMobile.app
```

**Requirements**: macOS 12+, Node.js 18+, tmux, cloudflared (`brew install node tmux cloudflare/cloudflare/cloudflared`)

## Troubleshooting

| Issue | Fix |
|-------|-----|
| App won't open | `open /Applications/VibeMobile.app` |
| "Apple cannot verify" | `xattr -cr /Applications/VibeMobile.app` |
| Server won't start | Check Node.js: `node --version` |
| No sessions | Check tmux: `tmux ls` |

## License

MIT - see [LICENSE](LICENSE)
