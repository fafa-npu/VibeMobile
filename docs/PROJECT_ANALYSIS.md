# VibeMobile 项目分析文档

## 1. 项目概述

### 1.1 项目定位
VibeMobile 是一个用于远程监控和控制 Claude Code 终端会话的工具套件。它允许用户通过手机或平板设备实时查看 Claude Code 的输出，并与之交互。

### 1.2 核心价值
- **移动办公**: 离开电脑后仍可监控 AI 编程助手的工作进度
- **实时交互**: 通过 WebSocket 实现毫秒级的输出更新
- **安全可控**: 设备配对和信任等级机制确保访问安全
- **远程访问**: 通过 Cloudflare Tunnel 实现公网访问

### 1.3 技术栈概览

| 组件 | 技术选型 | 说明 |
|------|----------|------|
| **后端服务** | Node.js + Express + TypeScript | 统一的 REST API 和 WebSocket 服务 |
| **前端 Web UI** | React 19 + Vite + TypeScript | 移动友好的 PWA 应用 |
| **桌面应用** | Flutter (macOS) | 本地服务管理和设备控制 |
| **会话管理** | tmux | 终端会话复用和管理 |
| **远程隧道** | Cloudflare Tunnel (cloudflared) | 安全的公网访问 |

---

## 2. 系统架构

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            用户设备                                      │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐               │
│  │   iPhone    │     │   iPad      │     │  Android    │               │
│  │  (Safari)   │     │  (Safari)   │     │  (Chrome)   │               │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘               │
│         │                   │                   │                       │
│         └───────────────────┼───────────────────┘                       │
│                             │                                           │
│                    HTTPS / WSS (公网或局域网)                            │
│                             │                                           │
└─────────────────────────────┼───────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │ Cloudflare Tunnel (可选)      │
              └───────────────┼───────────────┘
                              │
┌─────────────────────────────┼───────────────────────────────────────────┐
│                        开发者电脑 (macOS)                                │
│                             │                                           │
│  ┌──────────────────────────┴──────────────────────────┐               │
│  │              Node.js Server (Port 8765)             │               │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐    │               │
│  │  │ REST API   │  │ WebSocket  │  │ Static     │    │               │
│  │  │ /api/*     │  │ /ws        │  │ Files      │    │               │
│  │  └─────┬──────┘  └─────┬──────┘  └────────────┘    │               │
│  │        │               │                            │               │
│  │  ┌─────┴───────────────┴─────┐                     │               │
│  │  │     Core Services         │                     │               │
│  │  │  - TmuxManager            │                     │               │
│  │  │  - AuthService            │                     │               │
│  │  │  - OutputMonitor          │                     │               │
│  │  │  - WSManager              │                     │               │
│  │  └─────────────┬─────────────┘                     │               │
│  └────────────────┼──────────────────────────────────┘               │
│                   │                                                    │
│  ┌────────────────┴────────────────┐                                  │
│  │         tmux Sessions           │                                  │
│  │  ┌─────────┐ ┌─────────┐       │                                  │
│  │  │ vibe-1  │ │ vibe-2  │ ...   │                                  │
│  │  │ claude  │ │ claude  │       │                                  │
│  │  └─────────┘ └─────────┘       │                                  │
│  └─────────────────────────────────┘                                  │
│                                                                        │
│  ┌─────────────────────────────────────────────────────┐              │
│  │           Desktop App (Flutter)                      │              │
│  │  - 服务启停控制                                       │              │
│  │  - 设备配对管理                                       │              │
│  │  - Tunnel 开关                                       │              │
│  │  - 会话列表查看                                       │              │
│  └─────────────────────────────────────────────────────┘              │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.2 数据流

```
1. 会话输出流 (实时推送)
   tmux → OutputMonitor (轮询) → WSManager → WebSocket → Web UI

2. 命令输入流 (用户操作)
   Web UI → REST API → TmuxManager.sendKeys() → tmux session

3. 认证流 (设备配对)
   Web UI → 配对码请求 → Desktop App 审批 → JWT Token 颁发 → Cookie 存储
```

---

## 3. 目录结构

```
VibeMobile/
├── web/                          # 前端 + 后端 (Node.js 统一架构)
│   ├── src/                      # React 前端源码
│   │   ├── components/           # UI 组件
│   │   │   ├── CommandInput.tsx  # 命令输入框
│   │   │   ├── Header.tsx        # 页面头部
│   │   │   ├── LoadingScreen.tsx # 加载屏幕
│   │   │   ├── PairingScreen.tsx # 配对界面
│   │   │   ├── SessionCard.tsx   # 会话卡片
│   │   │   └── Terminal.tsx      # 终端输出显示
│   │   ├── pages/                # 页面组件
│   │   │   ├── SessionList.tsx   # 会话列表页
│   │   │   └── SessionDetail.tsx # 会话详情页
│   │   ├── services/             # 服务层
│   │   │   ├── api.ts            # REST API 封装
│   │   │   ├── auth.ts           # 认证服务
│   │   │   ├── notification.ts   # 通知服务
│   │   │   └── websocket.ts      # WebSocket 客户端
│   │   ├── stores/               # 状态管理 (Zustand)
│   │   │   ├── appStore.ts       # 应用状态
│   │   │   └── authStore.ts      # 认证状态
│   │   ├── hooks/                # React Hooks
│   │   ├── types/                # TypeScript 类型定义
│   │   ├── App.tsx               # 应用入口
│   │   └── main.tsx              # 渲染入口
│   │
│   ├── server/                   # Node.js 后端源码
│   │   ├── services/             # 核心服务
│   │   │   ├── tmux.ts           # tmux 会话管理
│   │   │   ├── auth.ts           # 认证服务 (JWT/配对)
│   │   │   ├── monitor.ts        # 输出监控
│   │   │   └── ws.ts             # WebSocket 管理
│   │   ├── routes/               # API 路由
│   │   │   ├── sessions.ts       # /api/sessions
│   │   │   ├── auth.ts           # /api/auth
│   │   │   └── notifications.ts  # /api/notifications
│   │   ├── middleware/           # 中间件
│   │   │   └── auth.ts           # 认证中间件
│   │   ├── config.ts             # 配置管理
│   │   ├── types.ts              # 类型定义
│   │   └── index.ts              # 服务器入口
│   │
│   ├── scripts/                  # 构建脚本
│   │   └── build-server.js       # 服务端打包脚本
│   ├── dist/                     # 构建输出
│   │   ├── server.cjs            # 打包后的服务端
│   │   └── *.js, *.css           # 前端静态资源
│   ├── package.json              # 依赖配置
│   ├── vite.config.ts            # Vite 配置
│   └── tsconfig.*.json           # TypeScript 配置
│
├── desktop/                      # Flutter 桌面应用
│   ├── lib/
│   │   ├── core/                 # 核心工具
│   │   │   ├── config/           # 应用配置
│   │   │   ├── logging/          # 日志系统
│   │   │   └── router/           # 路由配置
│   │   ├── data/                 # 数据层
│   │   │   └── models/           # 数据模型
│   │   ├── domain/               # 领域层
│   │   │   └── services/         # 业务服务
│   │   │       ├── server_service.dart   # 服务器管理
│   │   │       ├── auth_service.dart     # 认证服务
│   │   │       ├── tmux_service.dart     # tmux 服务
│   │   │       └── tunnel_service.dart   # 隧道服务
│   │   ├── presentation/         # 表现层
│   │   │   ├── providers/        # Riverpod Providers
│   │   │   └── screens/          # 页面
│   │   │       ├── home/         # 主页
│   │   │       ├── devices/      # 设备管理
│   │   │       ├── settings/     # 设置页
│   │   │       └── logs/         # 日志页
│   │   ├── app.dart              # App Widget
│   │   └── main.dart             # 入口
│   └── pubspec.yaml              # 依赖配置
│
├── docs/                         # 文档目录
├── certs/                        # SSL 证书 (本地生成)
└── README.md                     # 项目说明
```

---

## 4. 核心模块分析

### 4.1 后端服务 (web/server/)

#### 4.1.1 TmuxManager (tmux.ts)
**职责**: 封装所有 tmux 操作

```typescript
class TmuxManager {
  // 列出所有 vibe- 前缀的会话
  listSessions(): Session[]

  // 获取会话详情
  getSession(sessionId: string): Session | null

  // 捕获会话输出
  captureOutput(sessionId: string, withAnsi?: boolean): string | null

  // 发送按键到会话
  sendKeys(sessionId: string, text: string, pressEnter?: boolean): boolean

  // 发送特殊键 (Ctrl+C, Escape 等)
  sendSpecialKey(sessionId: string, key: string): boolean

  // 创建新会话
  createSession(command?: string): string | null

  // 终止会话
  killSession(sessionId: string): boolean
}
```

**关键实现**:
- 使用 `spawnSync` 调用 tmux 命令，避免 shell 解释问题
- 通过 `pgrep` 检测 claude 进程是否在运行
- 会话状态自动判断 (active/ended)

#### 4.1.2 AuthService (auth.ts)
**职责**: 设备认证和权限管理

**核心功能**:
- 配对码生成 (6位数字，5分钟有效)
- JWT Token 签发 (access_token: 15分钟, refresh_token: 30天)
- 设备管理 (注册、信任等级、活跃状态)
- 审计日志记录

**信任等级**:
| 等级 | 权限 |
|------|------|
| full | 创建/删除会话、发送命令、上传文件 |
| partial | 发送命令、上传文件 |
| view_only | 仅查看输出 |

#### 4.1.3 OutputMonitor (monitor.ts)
**职责**: 实时监控会话输出变化

```typescript
class OutputMonitor {
  // 启动单个会话监控
  startMonitoring(sessionId: string): void

  // 停止监控
  stopMonitoring(sessionId: string): void

  // 启动所有现有会话的监控
  startAll(): Promise<void>

  // 刷新会话列表
  refreshSessions(): void
}
```

**工作原理**:
1. 每 200ms 轮询 tmux 会话输出
2. 计算输出差异 (diff)
3. 通过 WebSocket 推送增量更新

#### 4.1.4 WSManager (ws.ts)
**职责**: WebSocket 连接和消息管理

**消息类型**:
| 类型 | 方向 | 说明 |
|------|------|------|
| connected | S→C | 连接成功确认 |
| ping/pong | C↔S | 心跳检测 |
| subscribe | C→S | 订阅会话 |
| subscribed | S→C | 订阅确认 |
| session.output | S→C | 输出更新 |
| session.status | S→C | 状态变更 |
| notification | S→C | 通知推送 |

### 4.2 前端应用 (web/src/)

#### 4.2.1 状态管理
使用 **Zustand** 进行轻量级状态管理:

- `appStore`: 当前选中的会话、UI 状态
- `authStore`: 认证状态、Token 管理

#### 4.2.2 核心组件

| 组件 | 功能 |
|------|------|
| SessionList | 会话列表展示，支持下拉刷新 |
| SessionDetail | 会话详情，包含终端输出和输入 |
| Terminal | 终端输出渲染，支持 ANSI 颜色 |
| CommandInput | 命令输入框，支持特殊键工具栏 |
| PairingScreen | 设备配对界面 |

#### 4.2.3 WebSocket 客户端
**自动重连机制**:
- 断开后 1s, 2s, 4s, 8s, 16s 指数退避重连
- 最多重试 5 次
- Token 过期自动刷新后重连

### 4.3 桌面应用 (desktop/)

#### 4.3.1 架构模式
采用 **Clean Architecture** + **Riverpod** 状态管理:

```
presentation (UI) → providers (状态) → domain (服务) → data (模型)
```

#### 4.3.2 核心服务

| 服务 | 职责 |
|------|------|
| ServerService | 启动/停止 Node.js 后端 |
| TmuxService | 本地 tmux 操作 |
| AuthService | WebSocket 连接和配对审批 |
| TunnelService | Cloudflare Tunnel 管理 |

#### 4.3.3 关键 Provider

| Provider | 状态 |
|----------|------|
| serverProvider | 服务器状态 (stopped/starting/running/error) |
| webProvider | Web 服务状态 (现已与 server 统一) |
| tunnelProvider | 隧道状态和公网 URL |
| sessionProvider | 会话列表 |
| settingsProvider | 用户设置 |

---

## 5. API 接口规范

### 5.1 REST API

#### Sessions API
```
GET    /api/sessions              # 列出所有会话
GET    /api/sessions/:id          # 获取会话详情
GET    /api/sessions/:id/output   # 获取完整输出
POST   /api/sessions              # 创建新会话
POST   /api/sessions/:id/send     # 发送命令 (支持 query 和 body)
POST   /api/sessions/:id/key      # 发送特殊键
POST   /api/sessions/:id/upload   # 上传文件
DELETE /api/sessions/:id          # 删除会话
```

#### Auth API
```
GET    /api/auth/status           # 认证状态
POST   /api/auth/pair/initiate    # 发起配对
POST   /api/auth/pair/complete    # 完成配对
POST   /api/auth/refresh          # 刷新 Token
POST   /api/auth/logout           # 登出
GET    /api/auth/devices          # 设备列表
DELETE /api/auth/devices/:id      # 删除设备
```

### 5.2 数据格式

#### Session (snake_case for frontend)
```json
{
  "session_id": "vibe-1",
  "project_path": "/path/to/project",
  "status": "active",
  "created_at": "2025-12-27T12:00:00.000Z",
  "updated_at": "2025-12-27T12:30:00.000Z",
  "output_tail": "最近1000字符的输出..."
}
```

---

## 6. 安全机制

### 6.1 认证流程

```
1. 用户在 Web UI 请求配对
2. 桌面端生成 6 位配对码 (5分钟有效)
3. 用户输入配对码
4. 桌面端弹窗确认
5. 服务端生成 JWT Token
6. Token 存储在 HttpOnly Cookie
7. 后续请求自动携带 Cookie
```

### 6.2 权限控制

- **本地请求**: 自动获得 full 权限
- **远程请求**: 根据设备 trustLevel 判断
- **高风险操作**: 创建/删除会话需要 full 权限
- **中风险操作**: 发送命令需要 partial 以上权限
- **审计日志**: 所有操作记录 IP、设备、时间

### 6.3 传输安全

- **本地开发**: mkcert 生成的自签名证书
- **远程访问**: Cloudflare Tunnel 提供的 HTTPS
- **WebSocket**: 始终使用 WSS (WebSocket Secure)

---

## 7. 构建与部署

### 7.1 开发模式

```bash
cd web
npm run dev  # 同时启动 Vite 和 Node.js 服务
```

### 7.2 生产构建

```bash
cd web
npm run build  # 构建前端 + 打包后端
# 输出: dist/server.cjs + 静态文件
```

### 7.3 桌面应用构建

```bash
cd desktop
flutter build macos --release
# 输出: build/macos/Build/Products/Release/VibeMobile.app
```

---

## 8. 代码统计

| 模块 | 文件数 | 代码行数 |
|------|--------|----------|
| Node.js 后端 (server/) | 10 | ~1,200 |
| React 前端 (src/) | 15 | ~1,500 |
| Flutter 桌面应用 (lib/) | 25 | ~4,500 |
| **总计** | **50** | **~7,200** |

---

## 9. 技术亮点

1. **统一后端架构**: Node.js 同时提供 API 和静态文件服务，简化部署
2. **实时输出推送**: 200ms 轮询 + WebSocket 推送，用户体验流畅
3. **安全配对机制**: 6位码 + 桌面确认双重验证
4. **跨平台支持**: PWA Web UI 支持任意浏览器，桌面应用支持 macOS
5. **优雅的错误处理**: 自动重连、Token 刷新、降级处理

---

## 10. 已知限制

1. **平台限制**: 桌面应用目前仅支持 macOS
2. **tmux 依赖**: 需要系统安装 tmux
3. **本地证书**: 首次使用需要信任自签名证书
4. **隧道依赖**: 远程访问需要安装 cloudflared

---

*文档版本: 1.0*
*更新日期: 2025-12-27*
