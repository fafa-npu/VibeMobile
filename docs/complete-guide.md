# VibeMobile 完整使用指南

> 远程监控和控制 Claude Code 会话的移动端解决方案

---

## 目录

1. [系统概述](#1-系统概述)
2. [系统要求](#2-系统要求)
3. [安装配置](#3-安装配置)
4. [Desktop 应用使用](#4-desktop-应用使用)
5. [Web UI 使用](#5-web-ui-使用)
6. [Cloudflare Tunnel 配置](#6-cloudflare-tunnel-配置)
7. [高级配置](#7-高级配置)
8. [故障排除](#8-故障排除)

---

## 1. 系统概述

### 1.1 什么是 VibeMobile？

VibeMobile 是一个远程监控和控制工具，允许你从移动设备（手机、平板）上：

- **实时查看** Claude Code 终端输出
- **远程发送** 消息和命令给 Claude
- **上传图片** 到 Claude Code 会话
- **发送特殊键** 如 Ctrl+C、Escape 等

### 1.2 系统架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                        你的 Mac 电脑                                │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐            │
│  │  Desktop    │    │ API Server  │    │  Web UI     │            │
│  │  (Flutter)  │───▶│  (FastAPI)  │◀───│  (React)    │            │
│  │             │    │  :8765      │    │  :5173      │            │
│  └─────────────┘    └─────────────┘    └─────────────┘            │
│         │                  │                  │                    │
│         │                  ▼                  │                    │
│         │          ┌─────────────┐            │                    │
│         │          │ Tmux 会话   │            │                    │
│         │          │(claude code)│            │                    │
│         │          └─────────────┘            │                    │
└─────────┼──────────────────────────────────────┼────────────────────┘
          │                                      │
          │      ┌──────────────────────┐        │
          └─────▶│  Cloudflare Tunnel   │◀───────┘
                 │  (远程访问通道)       │
                 └──────────────────────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │   移动设备浏览器      │
                 │  privatechannel1.    │
                 │  vibemobile.net      │
                 └──────────────────────┘
```

### 1.3 组件说明

| 组件 | 技术栈 | 端口 | 功能 |
|------|--------|------|------|
| **Desktop App** | Flutter (macOS) | - | 本地管理应用，控制服务启停 |
| **API Server** | Python FastAPI | 8765 | REST API + WebSocket 后端 |
| **Web UI** | React + Vite | 5173 | 移动端友好的 Web 界面 |
| **Tunnel** | cloudflared | - | 安全的远程访问通道 |

### 1.4 数据流

```
移动设备浏览器
      │
      ▼ (HTTPS)
Cloudflare Tunnel (privatechannel1.vibemobile.net)
      │
      ├──▶ /api/* ──▶ API Server (:8765) ──▶ Tmux 会话
      ├──▶ /ws     ──▶ WebSocket (:8765) ──▶ 实时输出
      └──▶ /*      ──▶ Web UI (:5173)    ──▶ React 应用
```

---

## 2. 系统要求

### 2.1 硬件要求

- **Mac 电脑** (macOS 12.0+)
- **移动设备** (iPhone/iPad/Android) 用于远程访问

### 2.2 软件依赖

#### 必需软件

| 软件 | 版本要求 | 用途 | 安装命令 |
|------|----------|------|----------|
| **Python** | 3.11+ | API Server 运行环境 | `brew install python@3.11` |
| **Node.js** | 18+ | Web UI 构建运行 | `brew install node` |
| **Flutter** | 3.5+ | Desktop App 构建 | [flutter.dev](https://flutter.dev) |
| **tmux** | 3.0+ | 会话管理 | `brew install tmux` |
| **mkcert** | - | 生成本地 HTTPS 证书 | `brew install mkcert` |

#### 可选软件

| 软件 | 用途 | 安装命令 |
|------|------|----------|
| **cloudflared** | 远程访问隧道 | `brew install cloudflared` |
| **uv** | Python 包管理器（推荐） | `brew install uv` |

### 2.3 网络要求

#### 本地访问模式
- 移动设备与 Mac 在同一局域网
- Mac 防火墙允许 5173、8765 端口

#### 远程访问模式（推荐）
- Cloudflare 账号
- 自定义域名（可选，或使用 TryCloudflare 临时域名）

### 2.4 检查依赖安装

运行以下命令验证所有依赖：

```bash
# 检查 Python
python3 --version  # 应显示 3.11+

# 检查 Node.js
node --version     # 应显示 v18+

# 检查 Flutter
flutter --version  # 应显示 3.5+

# 检查 tmux
tmux -V           # 应显示 tmux 3.x

# 检查 mkcert
mkcert --version  # 应显示版本号

# 检查 cloudflared（可选）
cloudflared --version
```

---

## 3. 安装配置

### 3.1 克隆项目

```bash
git clone https://github.com/your-repo/VibeMobile.git
cd VibeMobile
```

### 3.2 生成 SSL 证书

VibeMobile 使用 HTTPS 确保通信安全。首先需要生成本地 SSL 证书：

```bash
# 1. 安装 mkcert 根证书（首次运行）
mkcert -install

# 2. 创建证书目录
mkdir -p certs

# 3. 生成证书
mkcert -key-file certs/localhost-key.pem -cert-file certs/localhost.pem localhost 127.0.0.1
```

**验证证书生成成功：**
```bash
ls -la certs/
# 应看到 localhost.pem 和 localhost-key.pem 两个文件
```

### 3.3 安装 API Server 依赖

#### 方式一：使用 uv（推荐）

```bash
# 安装 uv（如果还没安装）
brew install uv

# 安装依赖
uv sync
```

#### 方式二：使用 pip

```bash
# 创建虚拟环境
python3 -m venv .venv
source .venv/bin/activate

# 安装依赖
pip install -e .
```

### 3.4 安装 Web UI 依赖

```bash
cd web
npm install
cd ..
```

### 3.5 构建 Desktop App

```bash
cd desktop
flutter pub get
flutter build macos --release
cd ..
```

构建完成后，应用位于：
```
desktop/build/macos/Build/Products/Release/VibeMobile.app
```

可以将其拖到 `/Applications` 目录使用。

### 3.6 验证安装

#### 测试 API Server

```bash
# 启动 API Server
uv run python -m server.main

# 另开终端，测试健康检查
curl -k https://localhost:8765/health
# 应返回: {"status":"healthy"}
```

#### 测试 Web UI

```bash
cd web
npm run dev
# 访问 https://localhost:5173
```

### 3.7 目录结构

安装完成后的目录结构：

```
VibeMobile/
├── certs/                    # SSL 证书
│   ├── localhost.pem         # 证书文件
│   └── localhost-key.pem     # 私钥文件
├── server/                   # API Server (Python)
├── web/                      # Web UI (React)
├── desktop/                  # Desktop App (Flutter)
│   └── build/macos/...       # 构建产物
└── .venv/ 或 uv.lock         # Python 依赖
```

---

*下一部分：Desktop 应用使用*

---

## 4. Desktop 应用使用

### 4.1 启动应用

**方式一：** 双击 `VibeMobile.app`（如果已安装到 Applications）

**方式二：** 开发模式运行
```bash
cd desktop
flutter run -d macos
```

### 4.2 主界面概览

```
┌─────────────────────────────────────────────────────────────────┐
│  VibeMobile                                         [设置] [_][x]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   API Server    │  │    Web UI       │  │    Tunnel       │ │
│  │    ● 运行中     │  │    ● 运行中     │  │    ○ 未启动     │ │
│  │   :8765        │  │   :5173         │  │                 │ │
│  │   [停止]       │  │   [停止]        │  │   [启动]        │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ 会话列表                                            [+ 新建]││
│  ├─────────────────────────────────────────────────────────────┤│
│  │ ○ vibe-main       活跃   12:30   [打开] [终止]             ││
│  │ ○ vibe-debug      活跃   11:45   [打开] [终止]             ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ 已配对设备                                      [生成配对码]││
│  ├─────────────────────────────────────────────────────────────┤│
│  │ iPhone 15 Pro    完全信任    最后活跃: 5分钟前   [管理]    ││
│  │ iPad Air         只读       最后活跃: 2小时前    [管理]    ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  [全部启动]                              [全部停止]             │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3 服务管理

#### 启动所有服务

点击 **"全部启动"** 按钮，将依次启动：
1. API Server（端口 8765）
2. Web UI（端口 5173）

#### 单独启动服务

- **API Server**: 点击 API Server 卡片的 "启动" 按钮
- **Web UI**: 点击 Web UI 卡片的 "启动" 按钮
- **Tunnel**: 点击 Tunnel 卡片的 "启动" 按钮

#### 服务状态指示

| 状态 | 图标 | 说明 |
|------|------|------|
| 运行中 | ● 绿色 | 服务正常运行 |
| 启动中 | ○ 黄色 | 服务正在启动 |
| 已停止 | ○ 灰色 | 服务未运行 |
| 错误 | ● 红色 | 服务出错 |

### 4.4 会话管理

#### 创建新会话

1. 点击会话列表右上角的 **"+ 新建"** 按钮
2. 输入会话名称（可选，默认为 `vibe-{timestamp}`）
3. 选择工作目录
4. 点击 "创建"

新会话将在终端应用（Terminal.app 或 iTerm2）中打开。

#### 打开现有会话

点击会话行的 **"打开"** 按钮，将在终端应用中附加到该会话。

#### 终止会话

点击会话行的 **"终止"** 按钮，将终止该 tmux 会话及其中运行的所有程序。

### 4.5 设备配对

#### 生成配对码

1. 点击设备列表右上角的 **"生成配对码"** 按钮
2. 显示一个 6 位数字配对码
3. 配对码有效期 5 分钟

#### 配对流程

```
Desktop App                    Mobile Browser
    │                              │
    │  1. 生成配对码 (123456)       │
    │  ◄──────────────────────────│ 2. 输入配对码
    │                              │
    │  3. 显示配对请求             │
    │     "iPhone 15 Pro 请求配对"  │
    │     [批准] [拒绝]            │
    │                              │
    │  4. 点击 [批准]              │
    │  ──────────────────────────►│ 5. 配对成功
    │                              │    显示会话列表
```

#### 管理已配对设备

点击设备行的 **"管理"** 按钮，可以：
- **更改信任级别**：完全信任 / 部分信任 / 只读
- **查看活动日志**：该设备的操作记录
- **取消配对**：移除该设备的访问权限

### 4.6 信任级别说明

| 级别 | 权限 | 适用场景 |
|------|------|----------|
| **完全信任** | 所有操作，包括创建/终止会话 | 自己的设备 |
| **部分信任** | 发送消息、上传文件 | 临时使用的设备 |
| **只读** | 仅查看会话输出 | 演示或监控用途 |

### 4.7 设置

点击右上角 **"设置"** 图标，可配置：

| 设置项 | 默认值 | 说明 |
|--------|--------|------|
| API 端口 | 8765 | API Server 监听端口 |
| Web 端口 | 5173 | Web UI 监听端口 |
| 会话前缀 | vibe | tmux 会话名称前缀 |
| 终端应用 | Terminal | 打开会话使用的终端（Terminal/iTerm） |
| 开机启动 | 否 | 是否随系统启动 |
| 自动启动服务 | 否 | 启动应用时自动启动所有服务 |
| Tunnel 名称 | 空 | 自定义 Cloudflare Tunnel 名称 |
| Tunnel 域名 | 空 | 自定义域名（如 privatechannel1.vibemobile.net） |
| 代理地址 | 空 | cloudflared 使用的代理（如 http://127.0.0.1:7890） |

### 4.8 快速开始流程

```bash
# 1. 启动 Desktop App
open /Applications/VibeMobile.app

# 2. 点击 "全部启动" 启动 API 和 Web

# 3. 点击 "启动 Tunnel"（可选，用于远程访问）

# 4. 在移动设备上打开 Tunnel URL 或 https://localhost:5173

# 5. 输入配对码完成配对

# 6. 开始远程控制 Claude Code！
```

---

*下一部分：Web UI 使用*

---

## 5. Web UI 使用

### 5.1 访问 Web UI

#### 本地访问（同一网络）

```
https://localhost:5173
```

或使用 Mac 的 IP 地址：
```
https://192.168.x.x:5173
```

**注意：** 首次访问时浏览器会显示证书警告，需要点击"继续访问"。

#### 远程访问（通过 Tunnel）

使用 Cloudflare Tunnel 配置的域名：
```
https://privatechannel1.vibemobile.net
```

### 5.2 设备配对

首次访问时，Web UI 会显示配对界面：

```
┌─────────────────────────────────────────┐
│                                         │
│           设备配对                       │
│                                         │
│  请输入 Desktop 应用显示的 6 位配对码    │
│                                         │
│     ┌───┬───┬───┬───┬───┬───┐         │
│     │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │         │
│     └───┴───┴───┴───┴───┴───┘         │
│                                         │
│           [ 配对 ]                      │
│                                         │
│  没有配对码？在 Desktop 应用中生成       │
│                                         │
└─────────────────────────────────────────┘
```

#### 配对步骤

1. 在 Desktop App 中点击 "生成配对码"
2. 在 Web UI 输入 6 位配对码
3. 点击 "配对" 按钮
4. 在 Desktop App 中批准配对请求
5. 配对成功后自动进入会话列表

### 5.3 主界面

配对成功后，显示会话列表：

```
┌─────────────────────────────────────────┐
│  VibeMobile                    [退出]   │
├─────────────────────────────────────────┤
│                                         │
│  活跃会话                               │
│                                         │
│  ┌─────────────────────────────────────┐│
│  │ vibe-main                          ││
│  │ 工作目录: ~/projects/myapp         ││
│  │ 运行时长: 2小时15分                 ││
│  │                          [进入会话] ││
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─────────────────────────────────────┐│
│  │ vibe-debug                         ││
│  │ 工作目录: ~/projects/api           ││
│  │ 运行时长: 45分                      ││
│  │                          [进入会话] ││
│  └─────────────────────────────────────┘│
│                                         │
│  [+ 创建新会话]                         │
│                                         │
└─────────────────────────────────────────┘
```

### 5.4 会话交互界面

点击 "进入会话" 后，显示终端交互界面：

```
┌─────────────────────────────────────────┐
│  ← vibe-main                           │
├─────────────────────────────────────────┤
│                                         │
│  $ claude                               │
│                                         │
│  ╭─────────────────────────────────────╮│
│  │ 我来帮你分析这段代码...             ││
│  │                                     ││
│  │ 这个函数主要做了以下几件事：        ││
│  │ 1. 首先验证输入参数                 ││
│  │ 2. 然后调用 API 获取数据            ││
│  │ 3. 最后格式化输出结果               ││
│  │                                     ││
│  │ 建议优化：                          ││
│  │ - 添加错误处理                      ││
│  │ - 使用缓存减少 API 调用             ││
│  ╰─────────────────────────────────────╯│
│                                         │
│  ● Claude 正在思考...                   │
│                                         │
├─────────────────────────────────────────┤
│  [Ctrl+C] [Esc] [↵] [📷]               │
│  ┌─────────────────────────────────────┐│
│  │ 请帮我优化这个函数的性能...        ││
│  └─────────────────────────────────────┘│
│                        [发送]           │
└─────────────────────────────────────────┘
```

### 5.5 交互功能

#### 发送消息

在底部输入框中输入消息，点击 "发送" 或按回车键发送。

#### 特殊键

| 按钮 | 功能 | 说明 |
|------|------|------|
| **Ctrl+C** | 中断 | 中断当前命令执行 |
| **Esc** | 取消 | 取消当前操作或退出模式 |
| **↵ Enter** | 确认 | 发送回车键 |
| **📷 图片** | 上传图片 | 上传截图或图片给 Claude |

#### 上传图片

1. 点击 📷 按钮
2. 选择图片文件（支持 PNG、JPG、GIF）
3. 图片将发送到当前 Claude Code 会话

**使用场景：**
- 截图展示 UI 问题
- 发送设计稿图片
- 分享错误截图

#### 实时输出

- 终端输出通过 WebSocket 实时推送
- 自动滚动到最新内容
- 支持 ANSI 颜色显示

### 5.6 权限限制

根据设备信任级别，部分功能可能受限：

| 功能 | 完全信任 | 部分信任 | 只读 |
|------|:--------:|:--------:|:----:|
| 查看输出 | ✓ | ✓ | ✓ |
| 发送消息 | ✓ | ✓ | ✗ |
| 上传图片 | ✓ | ✓ | ✗ |
| 发送特殊键 | ✓ | ✓ | ✗ |
| 创建会话 | ✓ | ✗ | ✗ |
| 终止会话 | ✓ | ✗ | ✗ |

### 5.7 断线重连

如果网络断开，Web UI 会自动尝试重连：

```
┌─────────────────────────────────────────┐
│  ⚠️ 连接已断开                          │
│                                         │
│  正在尝试重新连接... (3/5)              │
│                                         │
│  [手动重连]                             │
└─────────────────────────────────────────┘
```

重连成功后会恢复到之前的会话。

### 5.8 移动端优化

Web UI 针对移动设备进行了优化：

- **响应式布局**：适配各种屏幕尺寸
- **触摸友好**：按钮足够大，易于点击
- **软键盘适配**：输入时自动调整布局
- **横屏支持**：横屏时显示更多内容
- **PWA 支持**：可添加到主屏幕（即将支持）

---

*下一部分：Cloudflare Tunnel 配置*

---

## 6. Cloudflare Tunnel 配置

Cloudflare Tunnel 允许你从任何地方安全地访问 VibeMobile，无需公网 IP 或端口映射。

### 6.1 两种 Tunnel 模式

| 模式 | 域名 | 持久性 | 适用场景 |
|------|------|--------|----------|
| **Quick Tunnel** | 随机 `.trycloudflare.com` | 每次启动变化 | 临时使用、测试 |
| **Named Tunnel** | 自定义域名 | 永久固定 | 长期使用、生产环境 |

### 6.2 Quick Tunnel（快速隧道）

最简单的方式，无需任何配置：

1. 在 Desktop App 中点击 **"启动 Tunnel"**
2. 等待连接成功，显示类似：
   ```
   https://abc123-xyz.trycloudflare.com
   ```
3. 在移动设备上打开此 URL

**缺点：**
- URL 每次启动都会变化
- 无法使用自定义域名
- 无法配置 Cloudflare Access 等高级功能

### 6.3 Named Tunnel（命名隧道）

使用自定义域名的永久隧道，推荐用于长期使用。

#### 前提条件

- Cloudflare 账号
- 已添加到 Cloudflare 的域名（如 `vibemobile.net`）
- 安装 cloudflared CLI

#### 步骤 1：登录 Cloudflare

```bash
cloudflared login
```

浏览器会打开 Cloudflare 登录页面，选择要使用的域名并授权。

#### 步骤 2：创建 Tunnel

```bash
# 创建名为 VibeMobile 的 tunnel
cloudflared tunnel create VibeMobile

# 输出类似：
# Created tunnel VibeMobile with id 0c18c362-77a4-4a22-ab5c-114f39f6ceca
```

记录 Tunnel ID，后续会用到。

#### 步骤 3：配置 DNS 路由

```bash
# 将域名指向 tunnel
cloudflared tunnel route dns VibeMobile privatechannel1.vibemobile.net
```

这会在 Cloudflare DNS 中创建一条 CNAME 记录。

#### 步骤 4：创建配置文件

创建 `~/.cloudflared/config.yml`：

```yaml
# Tunnel 标识
tunnel: VibeMobile
credentials-file: /Users/你的用户名/.cloudflared/0c18c362-77a4-4a22-ab5c-114f39f6ceca.json

ingress:
  # API 端点 - 代理到后端服务器（必须以 /api/ 开头）
  - hostname: privatechannel1.vibemobile.net
    path: ^/api/.*$
    service: https://localhost:8765
    originRequest:
      noTLSVerify: true

  # WebSocket 端点（精确匹配）
  - hostname: privatechannel1.vibemobile.net
    path: ^/ws$
    service: https://localhost:8765
    originRequest:
      noTLSVerify: true

  # 健康检查
  - hostname: privatechannel1.vibemobile.net
    path: ^/health$
    service: https://localhost:8765
    originRequest:
      noTLSVerify: true

  # Web UI - 默认路由（使用自签名证书的 HTTPS）
  - hostname: privatechannel1.vibemobile.net
    service: https://localhost:5173
    originRequest:
      noTLSVerify: true

  # 兜底规则
  - service: http_status:404
```

**关键配置说明：**

| 配置项 | 说明 |
|--------|------|
| `tunnel` | Tunnel 名称，与创建时一致 |
| `credentials-file` | 凭证文件路径（创建 tunnel 时自动生成） |
| `path: ^/api/.*$` | **正则表达式**，只匹配以 `/api/` 开头的路径 |
| `noTLSVerify: true` | 允许本地服务使用自签名证书 |
| `service: http_status:404` | 所有未匹配的请求返回 404 |

**路由优先级：**
1. `/api/*` → API Server (8765)
2. `/ws` → WebSocket (8765)
3. `/health` → Health Check (8765)
4. `/*` → Web UI (5173)

#### 步骤 5：测试 Tunnel

```bash
# 手动运行 tunnel
cloudflared tunnel run VibeMobile

# 看到以下输出表示成功：
# INF Connection registered connIndex=0 ...
# INF Connection registered connIndex=1 ...
```

在浏览器访问 `https://privatechannel1.vibemobile.net` 验证。

#### 步骤 6：在 Desktop App 中配置

1. 打开 Desktop App 设置
2. 填写：
   - **Tunnel 名称**: `VibeMobile`
   - **Tunnel 域名**: `https://privatechannel1.vibemobile.net`
3. 保存设置
4. 点击 "启动 Tunnel"

现在 Desktop App 会使用命名隧道而不是快速隧道。

### 6.4 配置 Cloudflare Access（可选）

添加身份验证层，只允许授权用户访问：

#### 步骤 1：创建 Access 应用

1. 登录 [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. 进入 **Access** → **Applications**
3. 点击 **Add an application** → **Self-hosted**
4. 配置：
   - **Application name**: VibeMobile
   - **Application domain**: `privatechannel1.vibemobile.net`
   - **Session duration**: 24 hours（或根据需要）

#### 步骤 2：配置访问策略

1. 添加 Policy：
   - **Policy name**: Allow Authorized Users
   - **Action**: Allow
   - **Include**:
     - Emails: `your-email@example.com`
     - 或 Emails ending in: `@your-domain.com`

2. 保存并发布

#### 步骤 3：验证

访问 `https://privatechannel1.vibemobile.net`，应该会：
1. 重定向到 Cloudflare 登录页面
2. 输入邮箱收到验证码
3. 验证后访问 VibeMobile

### 6.5 常见配置问题

#### 问题：路径匹配错误

**症状：** 访问 `/src/services/api.ts` 返回 API 服务器的 404

**原因：** 路径模式 `/api/*` 使用子字符串匹配，包含 "api" 的路径都会匹配

**解决：** 使用正则表达式 `^/api/.*$` 确保只匹配以 `/api/` 开头的路径

#### 问题：无法连接到 origin service

**症状：** 错误信息 "Unable to reach origin service http://localhost:5173"

**原因：** Web UI 使用 HTTPS，不是 HTTP

**解决：** 将 service 改为 `https://localhost:5173` 并添加 `noTLSVerify: true`

#### 问题：Tunnel 不存在

**症状：** 错误 "VibeMobile is neither the ID nor the name of any of your tunnels"

**原因：** 没有创建 tunnel，可能只创建了 Cloudflare Access Application

**解决：** 运行 `cloudflared tunnel create VibeMobile` 创建真正的 tunnel

### 6.6 Tunnel 命令参考

```bash
# 查看所有 tunnel
cloudflared tunnel list

# 查看 tunnel 详情
cloudflared tunnel info VibeMobile

# 删除 tunnel
cloudflared tunnel delete VibeMobile

# 手动运行 tunnel
cloudflared tunnel run VibeMobile

# 查看配置
cloudflared tunnel configuration VibeMobile

# 测试配置文件
cloudflared tunnel ingress validate

# 查看路由规则
cloudflared tunnel route show
```

---

*下一部分：高级配置与故障排除*

---

## 7. 高级配置

### 7.1 环境变量

API Server 支持以下环境变量：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `VIBE_HOST` | `0.0.0.0` | 服务器绑定地址 |
| `VIBE_PORT` | `8765` | 服务器端口 |
| `VIBE_SSL_CERTFILE` | `certs/localhost.pem` | SSL 证书路径 |
| `VIBE_SSL_KEYFILE` | `certs/localhost-key.pem` | SSL 私钥路径 |

**示例：**
```bash
VIBE_PORT=9000 uv run python -m server.main
```

### 7.2 Desktop App 设置文件

设置存储在 `~/.vibemobile/settings.json`：

```json
{
  "api_port": 8765,
  "web_port": 5173,
  "session_prefix": "vibe",
  "auto_start_server": false,
  "launch_at_login": false,
  "terminal_app": "terminal",
  "enable_tunnel": false,
  "tunnel_name": "VibeMobile",
  "tunnel_hostname": "https://privatechannel1.vibemobile.net",
  "proxy_url": "http://127.0.0.1:7890"
}
```

### 7.3 代理配置

如果你在网络受限环境，需要配置代理：

#### cloudflared 代理

在 Desktop App 设置中配置 **代理地址**，或设置环境变量：

```bash
export HTTPS_PROXY=http://127.0.0.1:7890
cloudflared tunnel run VibeMobile
```

### 7.4 自定义证书

如果需要使用不同的 SSL 证书：

```bash
# 生成包含自定义域名的证书
mkcert -key-file certs/custom-key.pem -cert-file certs/custom.pem \
  localhost 127.0.0.1 192.168.1.100 myhost.local

# 启动时指定证书
VIBE_SSL_CERTFILE=certs/custom.pem \
VIBE_SSL_KEYFILE=certs/custom-key.pem \
uv run python -m server.main
```

### 7.5 Web UI 生产构建

生产环境建议使用构建后的静态文件：

```bash
cd web
npm run build

# 构建产物在 web/dist/
# 可使用 nginx 或其他静态服务器托管
```

### 7.6 API 端点参考

| 端点 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 健康检查 |
| `/api/sessions` | GET | 列出所有会话 |
| `/api/sessions` | POST | 创建新会话 |
| `/api/sessions/{id}` | GET | 获取会话详情 |
| `/api/sessions/{id}` | DELETE | 终止会话 |
| `/api/sessions/{id}/output` | GET | 获取会话输出 |
| `/api/sessions/{id}/send` | POST | 发送命令到会话 |
| `/api/sessions/{id}/key` | POST | 发送特殊键 |
| `/api/sessions/{id}/upload` | POST | 上传文件 |
| `/api/auth/pair/initiate` | POST | 生成配对码 |
| `/api/auth/pair/complete` | POST | 完成配对 |
| `/api/auth/refresh` | POST | 刷新访问令牌 |
| `/api/auth/devices` | GET | 列出已配对设备 |
| `/ws` | WebSocket | 实时更新通道 |

---

## 8. 故障排除

### 8.1 证书问题

#### 症状：浏览器显示 "您的连接不是私密连接"

**解决方案：**

1. 确保已安装 mkcert 根证书：
   ```bash
   mkcert -install
   ```

2. 在浏览器中手动信任证书：
   - Chrome: 点击 "高级" → "继续访问"
   - Safari: 点击 "显示详细信息" → "访问此网站"

3. 重新生成证书：
   ```bash
   cd certs
   rm *.pem
   mkcert -key-file localhost-key.pem -cert-file localhost.pem localhost 127.0.0.1
   ```

### 8.2 服务无法启动

#### 症状：API Server 启动失败

**检查步骤：**

```bash
# 1. 检查端口是否被占用
lsof -i :8765

# 2. 检查证书文件是否存在
ls -la certs/

# 3. 检查 Python 依赖
uv sync

# 4. 查看详细错误
uv run python -m server.main 2>&1
```

#### 症状：Web UI 启动失败

```bash
# 1. 检查 Node.js 版本
node --version  # 需要 18+

# 2. 重新安装依赖
cd web
rm -rf node_modules
npm install

# 3. 检查端口
lsof -i :5173
```

### 8.3 WebSocket 连接问题

#### 症状：实时输出不更新

**检查步骤：**

1. 确认 API Server 正在运行
2. 检查浏览器控制台是否有 WebSocket 错误
3. 确认访问 token 未过期（重新配对设备）

**常见原因：**
- 网络不稳定
- 防火墙阻止 WebSocket
- Token 过期

### 8.4 Tunnel 问题

#### 症状：Tunnel 启动超时

```bash
# 检查 cloudflared 是否正常
cloudflared --version

# 检查网络连接
curl -I https://cloudflare.com

# 如果使用代理，确保代理配置正确
export HTTPS_PROXY=http://127.0.0.1:7890
cloudflared tunnel run VibeMobile
```

#### 症状：通过 Tunnel 访问返回 404

1. 确认本地服务正在运行（API Server + Web UI）
2. 检查 `~/.cloudflared/config.yml` 配置
3. 验证路径匹配规则使用正则表达式
4. 重启 Tunnel：
   ```bash
   # 停止
   pkill cloudflared

   # 重启
   cloudflared tunnel run VibeMobile
   ```

### 8.5 会话问题

#### 症状：会话列表为空

```bash
# 检查 tmux 是否安装
tmux -V

# 列出现有会话
tmux ls

# 检查会话前缀
# 默认前缀是 "vibe"，会话名应该类似 "vibe-xxx"
```

#### 症状：无法创建新会话

1. 确认有足够的系统资源
2. 检查工作目录是否存在
3. 查看 Desktop App 日志

### 8.6 配对问题

#### 症状：配对码无效

- 配对码有效期 5 分钟，过期需重新生成
- 确保 Desktop App 和 Web UI 连接到同一个 API Server

#### 症状：配对请求不显示

1. 检查 Desktop App 是否在前台
2. 确认 API Server 正在运行
3. 检查网络连接

### 8.7 日志位置

| 组件 | 日志位置 |
|------|----------|
| API Server | 终端标准输出 |
| Desktop App | `~/Library/Logs/VibeMobile/` |
| cloudflared | 终端标准输出 |

### 8.8 重置所有设置

如果遇到无法解决的问题，可以重置：

```bash
# 1. 停止所有服务
pkill -f "python -m server.main"
pkill -f "npm run dev"
pkill cloudflared

# 2. 删除设置
rm -rf ~/.vibemobile/

# 3. 重新生成证书
cd certs
rm *.pem
mkcert -key-file localhost-key.pem -cert-file localhost.pem localhost 127.0.0.1

# 4. 重新启动
```

---

## 附录

### A. 快速命令参考

```bash
# 启动 API Server
uv run python -m server.main

# 启动 Web UI
cd web && npm run dev

# 启动 Tunnel（快速）
cloudflared tunnel --url https://localhost:5173

# 启动 Tunnel（命名）
cloudflared tunnel run VibeMobile

# 列出 tmux 会话
tmux ls

# 附加到会话
tmux attach -t vibe-xxx

# 查看日志
tail -f ~/Library/Logs/VibeMobile/app.log
```

### B. 端口速查表

| 服务 | 端口 | 协议 |
|------|------|------|
| API Server | 8765 | HTTPS |
| Web UI | 5173 | HTTPS |
| WebSocket | 8765 | WSS |

### C. 相关链接

- [Cloudflare Tunnel 文档](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [mkcert 项目](https://github.com/FiloSottile/mkcert)
- [tmux 手册](https://man7.org/linux/man-pages/man1/tmux.1.html)

---

**文档版本**: 1.0
**最后更新**: 2024-12-27
