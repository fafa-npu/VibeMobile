# VibeMobile 使用指南

> 让你在手机上远程监控和控制电脑上运行的 Claude Code 任务

---

## 快速开始（5 分钟上手）

### 前置条件

- macOS 或 Linux 系统
- 已安装 Claude Code CLI (`claude` 命令可用)
- Python 3.11+
- tmux（macOS: `brew install tmux`）

---

## 第一部分：电脑端设置

### 步骤 1：安装 VibeMobile

```bash
# 克隆项目
cd ~/Projects
git clone <your-repo> VibeMobile
cd VibeMobile

# 安装 Python 依赖
pip install -e .

# 添加 vibe-claude 到 PATH（可选，方便全局使用）
ln -s $(pwd)/server/cli/vibe-claude /usr/local/bin/vibe-claude
```

### 步骤 2：启动后端服务

```bash
# 启动 VibeMobile 服务（保持终端运行）
cd ~/Projects/VibeMobile
python -m server.main
```

成功启动后你会看到：
```
2025-12-24 - server.main - INFO - Starting VibeMobile server...
INFO:     Uvicorn running on http://0.0.0.0:8765 (Press CTRL+C to quit)
2025-12-24 - server.main - INFO - Server running on http://0.0.0.0:8765
```

**验证服务运行：**
```bash
# 在另一个终端测试
curl http://localhost:8765/
# 应返回: {"name":"VibeMobile","version":"0.1.0","status":"running"}
```

### 步骤 3：使用 vibe-claude 启动 Claude 会话

现在，用 `vibe-claude` 代替 `claude` 启动你的开发会话：

```bash
# 方式 1：直接启动（最简单）
vibe-claude

# 方式 2：指定项目目录
cd ~/Projects/my-app
vibe-claude

# 方式 3：后台启动（不附加到会话）
vibe-claude --detach

# 方式 4：列出所有会话
vibe-claude --list

# 方式 5：附加到已有会话
vibe-claude --attach vibe-1
```

**会话命名规则：**
- 会话自动命名为 `vibe-1`, `vibe-2`, `vibe-3`...
- 你也可以指定名称：`vibe-claude --name my-task`

**在 tmux 会话中：**
- `Ctrl+B` 然后 `D`：分离会话（回到普通终端，Claude 继续运行）
- `Ctrl+B` 然后 `[`：进入滚动模式查看历史
- `Ctrl+C`：中断当前 Claude 操作

---

## 第二部分：外网访问配置

要在手机上访问，需要将本地服务暴露到公网。

### 方案 A：Cloudflare Tunnel（推荐）

**优点：** 手机无需安装额外 App，直接用浏览器访问

#### 1. 安装 cloudflared

```bash
# macOS
brew install cloudflare/cloudflare/cloudflared

# 或下载二进制
# https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/
```

#### 2. 登录 Cloudflare

```bash
cloudflared tunnel login
# 会打开浏览器，选择你的域名授权
```

#### 3. 创建 Tunnel

```bash
# 创建名为 vibemobile 的 tunnel
cloudflared tunnel create vibemobile

# 记下输出的 Tunnel ID，类似：
# Created tunnel vibemobile with id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

#### 4. 配置 Tunnel

创建配置文件 `~/.cloudflared/config.yml`：

```yaml
tunnel: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  # 你的 Tunnel ID
credentials-file: /Users/你的用户名/.cloudflared/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.json

ingress:
  - hostname: vibe.你的域名.com
    service: http://localhost:8765
  - service: http_status:404
```

#### 5. 配置 DNS

```bash
cloudflared tunnel route dns vibemobile vibe.你的域名.com
```

#### 6. 启动 Tunnel

```bash
# 前台运行（测试用）
cloudflared tunnel run vibemobile

# 或作为服务运行（推荐）
sudo cloudflared service install
sudo launchctl start com.cloudflare.cloudflared
```

#### 7. 配置访问控制（强烈建议）

在 Cloudflare Zero Trust Dashboard 中：
1. 进入 Access > Applications
2. 添加应用，域名填 `vibe.你的域名.com`
3. 配置认证方式（邮箱 OTP / GitHub / Google 等）

---

### 方案 B：Tailscale（私有网络）

**优点：** 更安全，只有你的设备能访问

#### 1. 安装 Tailscale

```bash
# macOS
brew install tailscale

# 启动
sudo tailscaled &
tailscale up
```

#### 2. 手机安装 Tailscale

- iOS: App Store 搜索 "Tailscale"
- Android: Google Play 搜索 "Tailscale"
- 用同一账号登录

#### 3. 获取电脑的 Tailscale IP

```bash
tailscale ip -4
# 输出类似: 100.x.x.x
```

#### 4. 手机访问

在手机浏览器打开：`http://100.x.x.x:8765`

---

## 第三部分：手机端使用

### 首次访问

1. **打开浏览器**，输入你配置的地址：
   - Cloudflare Tunnel: `https://vibe.你的域名.com`
   - Tailscale: `http://100.x.x.x:8765`

2. **完成认证**（如果配置了 Cloudflare Access）

3. **添加到主屏幕**（可选，推荐）
   - iOS Safari: 点击分享按钮 → "添加到主屏幕"
   - Android Chrome: 菜单 → "添加到主屏幕"

### 日常使用流程

#### 场景 1：出门前在电脑上启动任务

```bash
# 电脑上
cd ~/Projects/my-app
vibe-claude

# 给 Claude 下达任务
> 帮我重构 UserService，完成后运行测试

# 按 Ctrl+B 然后 D 分离会话
# 现在你可以离开电脑了
```

#### 场景 2：在手机上监控进度

1. 打开 VibeMobile（从主屏幕图标或浏览器）
2. 看到会话列表，点击 `vibe-1`
3. 查看 Claude 的实时输出
4. 状态显示 "运行中" 表示 Claude 还在工作

#### 场景 3：在手机上发送指令

当你看到 Claude 需要指导时：

1. 在输出区域底部的输入框输入指令
2. 例如：`测试失败了，请检查一下错误`
3. 点击发送
4. 几秒后看到 Claude 的响应

**常用快捷指令：**
- `继续` - 让 Claude 继续当前任务
- `运行测试` - 执行测试
- `撤销` - 撤销最近的修改
- `git status` - 查看 git 状态

#### 场景 4：回到电脑继续工作

```bash
# 附加回会话
vibe-claude --attach vibe-1

# 或者直接用 tmux
tmux attach -t vibe-1
```

---

## 第四部分：命令参考

### vibe-claude 命令

| 命令 | 说明 |
|------|------|
| `vibe-claude` | 启动新会话 |
| `vibe-claude --list` | 列出所有会话 |
| `vibe-claude --attach NAME` | 附加到会话 |
| `vibe-claude --detach` | 后台启动会话 |
| `vibe-claude --name NAME` | 指定会话名称 |
| `vibe-claude --help` | 显示帮助 |

### tmux 快捷键（在会话中）

| 快捷键 | 说明 |
|--------|------|
| `Ctrl+B` `D` | 分离会话 |
| `Ctrl+B` `[` | 滚动模式 |
| `Ctrl+B` `]` | 粘贴 |
| `q` | 退出滚动模式 |

### API 端点（高级用户）

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/api/sessions` | 获取所有会话 |
| GET | `/api/sessions/{id}` | 获取会话详情 |
| GET | `/api/sessions/{id}/output` | 获取会话输出 |
| POST | `/api/sessions/{id}/send?content=xxx` | 发送指令 |
| POST | `/api/sessions/{id}/key?key=C-c` | 发送特殊键 |
| DELETE | `/api/sessions/{id}` | 结束会话 |
| WS | `/ws` | WebSocket 实时推送 |

---

## 第五部分：典型工作流示例

### 示例 1：长时间重构任务

**早上（电脑前）：**
```bash
cd ~/Projects/legacy-app
vibe-claude

> 请帮我将整个项目从 JavaScript 迁移到 TypeScript。
> 按照以下步骤进行：
> 1. 先配置 tsconfig.json
> 2. 逐个文件转换，从入口文件开始
> 3. 每转换一个文件后运行测试确保没有破坏

# Ctrl+B D 分离，去开会
```

**中午（手机上）：**
- 打开 VibeMobile 查看进度
- 看到 Claude 卡在某个类型错误
- 发送：`这个类型用 unknown 替代 any 试试`
- Claude 继续工作

**下午（回到电脑）：**
```bash
vibe-claude --attach vibe-1
# 继续和 Claude 协作
```

### 示例 2：多任务并行

```bash
# 终端 1：启动前端任务
cd ~/Projects/frontend
vibe-claude --name frontend
> 实现用户设置页面的 UI

# Ctrl+B D 分离

# 终端 2：启动后端任务
cd ~/Projects/backend
vibe-claude --name backend
> 添加用户设置的 API 端点

# Ctrl+B D 分离
```

**手机上：**
- 看到两个会话：`frontend` 和 `backend`
- 可以分别点进去查看和发送指令
- 指令不会串到其他会话

---

## 第六部分：故障排除

### 问题 1：手机无法连接

**检查清单：**
1. 电脑上 VibeMobile 服务是否运行？
   ```bash
   curl http://localhost:8765/health
   ```
2. Cloudflare Tunnel / Tailscale 是否运行？
3. 手机网络是否正常？
4. 尝试刷新页面或重新打开

### 问题 2：WebSocket 断开

- 这是正常现象（手机切后台会断开）
- 重新打开页面会自动重连
- 重连后会获取最新状态

### 问题 3：指令发送后没反应

**可能原因：**
1. Claude 正在思考中，等待几秒
2. 网络延迟，刷新页面查看
3. 会话已结束，检查会话状态

### 问题 4：tmux 会话丢失

```bash
# 列出所有 tmux 会话
tmux list-sessions

# 如果会话存在但 vibe-claude --list 看不到
# 可能是会话名称不以 "vibe" 开头
tmux attach -t 会话名称
```

---

## 第七部分：安全建议

### 必须做

1. **启用认证**：使用 Cloudflare Access 或 Tailscale ACL
2. **使用 HTTPS**：Cloudflare Tunnel 自动提供
3. **定期检查**：查看访问日志，确保没有异常访问

### 不要做

1. **不要**直接暴露端口到公网（无认证）
2. **不要**使用简单密码
3. **不要**在公共 WiFi 下使用 HTTP 连接

---

## 快速参考卡片

### 电脑端

```bash
# 启动服务
python -m server.main

# 启动 Claude 会话
vibe-claude

# 分离会话
Ctrl+B D

# 列出会话
vibe-claude --list

# 附加会话
vibe-claude --attach vibe-1
```

### 手机端

1. 打开 `https://vibe.你的域名.com`
2. 点击会话查看详情
3. 底部输入框发送指令
4. 使用快捷按钮执行常用操作

---

## 下一步

- [ ] 配置外网访问（Cloudflare Tunnel 或 Tailscale）
- [ ] 在手机上添加到主屏幕
- [ ] 尝试第一个远程监控任务
- [ ] 熟悉手机端的操作

有问题？查看 [故障排除](#第六部分故障排除) 或提交 Issue。
