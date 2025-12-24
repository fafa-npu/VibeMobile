# VibeMobile 快速启动

## 一、每日启动（电脑端）

```bash
# 1. 启动 VibeMobile 服务（保持运行）
cd ~/Projects/VibeMobile
python -m server.main

# 2. 启动 Cloudflare Tunnel（如果使用）
cloudflared tunnel run vibemobile

# 3. 开始工作
cd ~/Projects/你的项目
vibe-claude
```

## 二、常用命令

| 操作 | 命令 |
|------|------|
| 启动新会话 | `vibe-claude` |
| 列出会话 | `vibe-claude --list` |
| 附加会话 | `vibe-claude --attach vibe-1` |
| 分离会话 | `Ctrl+B` 然后 `D` |
| 后台启动 | `vibe-claude --detach` |

## 三、手机端使用

1. 打开 `https://vibe.你的域名.com`（或 Tailscale IP）
2. 点击会话查看实时输出
3. 在底部输入框发送指令

## 四、快捷键

**tmux 会话内：**
- `Ctrl+B` `D` - 分离（回到普通终端）
- `Ctrl+B` `[` - 滚动查看历史
- `Ctrl+C` - 中断 Claude

## 五、检查状态

```bash
# 检查服务
curl http://localhost:8765/health

# 检查会话
vibe-claude --list

# 检查 tunnel
cloudflared tunnel info vibemobile
```
