# 技术可行性报告（VibeMobile：Claude Code CLI 远程状态与指令）

> 日期：2025-12-24

## 1. 结论摘要
本项目在当前时间点技术上**可行**。

- **远程状态（含输出流）**：可通过 Claude Code CLI 的 `--output-format=stream-json` 与 `--include-partial-messages` 获取实时/准实时输出片段，再通过 WebSocket 推送到手机端。
- **远程下发新指令（注入到指定任务）**：可通过“任务守护进程/会话管理层”实现，关键在于把 `taskId -> Claude 会话/进程` 做强绑定，避免并发串线。
- **外网访问**：可用 Cloudflare Tunnel（推荐）/Tailscale（推荐）/ngrok（开发期）实现，不要求自建公网 IP。

最大不确定点不在 WebSocket 或外网接入，而在 **Claude Code CLI 的“会话持续交互/注入”具体行为**（尤其是 `--print` + `--input-format=stream-json` 是否支持单进程多轮输入）。这部分需要优先做 POC 验证。

## 2. 范围与约束（来自需求）
- Claude Code 形态：CLI 工具
- 并发模型：同时多个任务并行
- 状态更新：推送（WebSocket）为主
- 客户端：先做 Web（可 PWA），未来可 Flutter
- 网络：必须外网访问
- 延迟目标：A1/A2/A3 均为 60s

## 3. 现状调研要点（2025-12）
### 3.1 Claude Code CLI 可用能力（从本机 `claude --help` 可验证）
Claude Code CLI 已暴露若干对“机器可控/可集成”非常关键的能力：
- `--print`：非交互模式输出并退出
- `--output-format`：支持 `text | json | stream-json`（实时流式 JSON）
- `--include-partial-messages`：输出包含 partial chunks（更适合实时 UI）
- `--input-format`：支持 `text | stream-json`（实时流式输入；但文档提示仅对 `--print` 生效）
- 会话相关：`--continue`、`--resume`、`--session-id`、`--no-session-persistence`

这些能力意味着：
- **输出采集/推送**可以走结构化流式 JSON，不必依赖屏幕抓取或解析纯文本。
- **多任务并行**可通过“每任务一个会话/进程 + 统一任务表”实现。

### 3.2 WebSocket 后端技术成熟度
FastAPI/Starlette 对 WebSocket 支持成熟，可实现：
- Web 端原生 WebSocket 客户端
- 服务端连接管理、断线重连
- 鉴权（Query token/Cookie/Header）

### 3.3 外网访问成熟方案
外网访问不建议直接暴露家庭路由器端口（攻击面大、运维成本高）。成熟方案分三类：

1) **Cloudflare Tunnel（推荐）**
- outbound-only 连接（服务端只需要出站连接）
- 可叠加 Cloudflare Access（OIDC/SAML/OTP 等）做身份/访问控制
- 适合“手机无需装 VPN 客户端，浏览器直接访问”

2) **Tailscale（推荐）**
- 设备间 WireGuard 组网，天然私网访问模型
- ACL 能力强，安全边界清晰
- 代价是手机端需要安装 Tailscale

3) **ngrok（开发期可用）**
- 上手快，适合 POC/演示
- 生产长期使用通常需要考虑成本、域名固定、策略与审计等

## 4. 推荐总体架构（可落地）
### 4.1 组件划分
- **Runner（电脑端守护进程）**
  - 启动/管理 Claude Code 任务（taskId）
  - 采集状态与输出
  - 接收手机端下发的 command 并路由到正确任务

- **API/WebSocket Server（可与 Runner 同进程）**
  - HTTP API：任务列表、任务详情、发送命令、查询命令状态
  - WebSocket：推送任务状态/输出增量

- **Web Client（手机端）**
  - 任务列表 + 任务详情（tail output）
  - command 输入与状态展示

- **外网接入层**
  - Cloudflare Tunnel / Tailscale / ngrok

### 4.2 数据/状态模型（最小）
- Task
  - `taskId`, `status`, `updatedAt`, `tailOutput`
- Command
  - `commandId`, `taskId`, `command`, `status`, `createdAt`, `updatedAt`, `resultTail`

> MVP 允许只保留最近 N 行或最近 M KB，避免无限增长。

## 5. “会话/任务注入”的实现路径（关键）
这里给出三条可行路线，按推荐顺序排序。

### 路线 A（优先推荐）：会话化管理 + `--resume/--session-id` 的“多进程多轮”模式
思路：不强依赖“在同一进程里持续写 stdin”。而是把每次手机下发 command 当作一次新的 CLI 调用，但通过 session 机制把上下文续在同一个会话里。

- 优点
  - 实现简单、鲁棒性强（进程可短生命周期）
  - 不需要 pty 注入，避免跨平台/交互细节
  - 与 WebSocket 推送自然契合：每次调用都可输出 stream-json

- 风险/未知
  - `--resume/--session-id` 在你的订阅/配置下是否可稳定使用
  - 会话持久化数据位置与并发访问行为需要确认

### 路线 B（高交互）：长期运行的 Claude 进程 + stdin 注入（pty）
思路：每个 task 启动一个长期存在的 `claude` 交互进程，通过 pseudo-terminal 把手机端 command 写入 stdin，读取 stdout。

- 优点
  - 真正意义上的“运行中注入”，交互体验最像本地

- 风险
  - pty/交互式提示/权限提示等会增加工程复杂度
  - 进程卡死、窗口大小、控制字符、权限对话等边界情况多

### 路线 C（可能性待验证）：`--print` + `--input-format=stream-json` 单进程持续输入
CLI help 提示 `--input-format` “only works with --print”，但不明确是否允许在同一进程中持续流式输入多条消息。

- 若可行
  - 将显著简化注入：一个 task = 一个 `--print` 进程 + stream-json 输入输出

- 建议
  - 作为 POC 的第一优先验证项（见第 8 节）

## 6. WebSocket 推送设计建议（与需求匹配）
### 6.1 推送内容
- Task 事件：`task.started | task.updated | task.finished`
- Output 事件：`task.output.append`（增量 chunk 或行）
- Command 事件：`command.received | command.running | command.succeeded | command.failed`

### 6.2 连接与重连
- 客户端断线后自动重连
- 服务端允许客户端带上 `lastSeenEventId`（或时间戳）做简单补偿
- MVP 可先不做复杂事件溯源，只保证“重连后能看到最新 tailOutput”满足 A4

## 7. 外网访问方案对比与推荐
### 7.1 推荐：Cloudflare Tunnel + Access
- 适用：你希望“手机浏览器直接访问”，不想要求手机安装额外客户端
- 优点：outbound-only、易接入 Access、可控性强
- 注意：需要 Cloudflare 账号与基本配置；Access 策略建议最少权限

### 7.2 备选：Tailscale
- 适用：你能接受手机装 Tailscale，并希望更像“私网”
- 优点：ACL 与设备管理能力强，安全边界清晰
- 注意：对“临时分享给他人”不是 MVP 目标

### 7.3 开发期：ngrok
- 适用：快速 POC/演示
- 注意：域名稳定性、访问策略与审计需评估

## 8. POC 验证计划（建议按顺序执行）
### POC-1：验证 stream-json 输出可用于实时推送
- 目标：确认 `--output-format=stream-json` + `--include-partial-messages` 能连续产出 chunk
- 成功标准：Runner 能持续读取并转发到 WebSocket，Web 端能看到增量输出

### POC-2：验证“注入/多轮交互”的最低成本路径
按优先级：
1) 验证 路线 C：`--print` + `--input-format=stream-json` 是否支持单进程多轮输入
2) 若不支持，验证 路线 A：`--session-id/--resume` 能否把多次命令串在同一会话上下文
3) 若 A 也不满足交互要求，再投入 路线 B（pty 长连接）

### POC-3：验证多任务并发不串线
- 同时启动 2 个 task
- 分别下发 command
- 成功标准：输出与 command 状态严格归属对应 taskId

### POC-4：验证外网访问
- Cloudflare Tunnel 或 Tailscale 任一方案打通
- 成功标准：手机蜂窝网络可访问 Web + WebSocket

## 9. 安全性与合规风险（必须重视）
这是一个“远程命令注入”系统，默认属于高风险控制面。

最低安全基线建议：
- 强制身份认证（Access/OIDC/一次性密码/至少 bearer token）
- TLS（若使用 Tunnel/Access 通常由其提供）
- 服务器端命令审计：记录 taskId、command、时间、发起人、结果
- 速率限制与简单的滥用防护

> 需求未要求命令 allowlist，但从风险控制角度，至少应支持“可选的命令白名单/黑名单策略”，否则一旦令牌泄露影响极大。

## 10. 复杂度与实现成本评估（定性）
- WebSocket 推送：低~中（成熟栈）
- 外网访问：低（使用 Tunnel/Tailscale）
- 多任务状态管理：中（需要任务表、日志截断、资源清理）
- Claude 会话注入：中~高（取决于 POC 结果；路线 A/C 可降到中，路线 B 可能到高）

## 11. 推荐落地方案（MVP）
- 后端：FastAPI（HTTP + WebSocket）
- Runner：Python `asyncio` + `subprocess`（按 task 管理子进程）
- 注入策略：优先走 路线 C→A，避免 pty
- 外网：Cloudflare Tunnel（默认） + Access；Tailscale 作为可选替代
- 存储：MVP 用 SQLite/本地文件均可（只存 task/command 元数据与 tail）

## 12. 下一步建议
1. 先做 POC-1/POC-2，尽快锁定“注入路线”
2. 再做最小 Web UI + WebSocket 推送，跑通 A1-A4
3. 最后再做外网接入与安全策略固化（不建议等到最后才考虑安全）
