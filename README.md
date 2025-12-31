# VibeMobile

Remote control for Claude Code sessions from your phone. **macOS only**.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/fafa-npu/VibeMobile/main/install.sh | bash
```

This installs dependencies and the app. After installation, restart Terminal or run `source ~/.zshrc`.

## Usage

1. **Start app** (in Terminal): `vibemobile`
2. **Start server**: Click "Start Server"
3. **Create session**: Click "New Session" → Select folder
4. **Connect from phone**:
   - Same network: `http://YOUR_MAC_IP:8765`
   - Remote: Click "Start Tunnel" → Copy URL
5. **Pair device**: App → Devices → "Generate Pairing Code" → Enter on phone

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
