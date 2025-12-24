# POC 验证报告

> 日期：2025-12-24
> 验证者：Claude Code

## 1. 验证目标

### 第一轮 POC（Headless 模式）
验证 Claude Code CLI 是否支持：
1. 流式 JSON 输出（用于实时推送到手机端）
2. 会话注入（向运行中的任务发送新指令）
3. 多任务并发（多个任务互不干扰）

### 第二轮 POC（tmux 方案）
验证 tmux 终端复用器是否可以：
1. 捕获 Claude 交互式终端的完整输出
2. 向 Claude 会话注入文本并执行
3. 保持与原有开发体验一致

---

## 2. 第一轮 POC: Headless 模式（参考）

> ⚠️ **用户反馈**: 此方案改变了开发体验，已被弃用。仅作为技术参考保留。

### POC-1: stream-json 输出格式

**测试命令：**
```bash
echo '写一个 Python hello world' | claude --print --output-format stream-json \
  --include-partial-messages --verbose
```

**结果：✅ 成功**

| 消息类型 | 用途 |
|----------|------|
| `system` | 初始化信息（session_id, tools, model 等）|
| `stream_event` | 流式事件容器 |
| `assistant` | 完整的助手消息 |
| `user` | 用户消息/工具结果 |
| `result` | 最终结果（包含 cost、usage 等）|

### POC-2: 会话注入能力

**方式 A：stream-json 输入（单进程多轮）** - ✅ 成功

**方式 B：session-id + resume（多进程会话续接）** - ✅ 成功

### POC-3: 多任务并发 - ✅ 成功

**结论**：技术上可行，但用户体验不佳（改变了日常开发方式）。

---

## 3. 第二轮 POC: tmux 终端复用方案 ⭐

> **采用方案**：保持原有交互式终端体验，通过 tmux 增加远程监控能力

### POC-A: tmux 输出捕获

**测试命令：**
```bash
# 创建会话
tmux new-session -d -s vibe-test "claude"

# 捕获输出
tmux capture-pane -t vibe-test -p -S -500
```

**结果：✅ 成功**

**捕获到的 Claude 启动界面：**
```
 * ▐▛███▜▌ *   Claude Code v2.0.76
* ▝▜█████▛▘ *  claude-opus-4.5 · API Usage Billing
 *  ▘▘ ▝▝  *   ~/Documents/repos/VibeMobile

  /model to try Opus 4.5

────────────────────────────────────────────────────────────────────────────────
>
────────────────────────────────────────────────────────────────────────────────
  ? for shortcuts
```

**关键发现：**
- `tmux capture-pane -p` 可以完整捕获终端输出
- `-S -500` 参数可以捕获历史记录（最近 500 行）
- 支持 ANSI 转义序列（可选 `-e` 参数保留颜色）

---

### POC-B: tmux 输入注入

**测试命令：**
```bash
# 发送文本
tmux send-keys -t vibe-test "hello"

# 发送回车提交
tmux send-keys -t vibe-test Enter
```

**结果：✅ 成功**

**关键发现：**
- `tmux send-keys` 可以向会话发送任意按键
- 文本和 Enter 需要分开发送（或一起发送如 `"hello" Enter`）
- 注入的文本在本地 tmux 会话中也会显示

---

### POC-C: 完整交互验证

**测试流程：**
1. 创建 tmux 会话运行 Claude
2. 发送 "hello" → 收到 "Hello! How can I help you today?"
3. 发送 "remember number 888" → 收到 "Got it, I'll remember the number 888."
4. 发送 "what number did I ask you to remember? reply only the number" → 收到 "888"

**完整输出捕获：**
```
> hello

⏺ Hello! How can I help you today?

> remember number 888

⏺ Got it, I'll remember the number 888.

> what number did I ask you to remember? reply only the number

⏺ 888
```

**结果：✅ 成功**

**验证项：**
- [x] 能捕获 Claude 交互式终端的完整输出
- [x] 能向 Claude 会话注入文本并执行
- [x] 注入的文本在本地终端也能看到
- [x] Claude 的上下文记忆正常工作

---

## 4. 技术路线最终决策

### 采用方案：tmux 终端复用器

| 特性 | Headless 模式 | tmux 方案 |
|------|--------------|-----------|
| 用户体验 | ❌ 改变开发方式 | ✅ 保持一致 |
| 输出捕获 | ✅ stream-json | ✅ capture-pane |
| 输入注入 | ⚠️ 需要会话续接 | ✅ send-keys |
| 本地可见性 | ❌ 无终端界面 | ✅ 完全可见 |
| 实现复杂度 | ⭐⭐⭐ | ⭐⭐ |

### tmux 方案优势

1. **保持原有体验**：用户仍然在终端中与 Claude 交互
2. **增量增强**：只是"增加"远程能力，而非"替代"
3. **完全可见**：本地和远程看到的内容完全一致
4. **易于调试**：可以直接 attach 到会话查看状态

### 实现要点

**启动会话：**
```bash
#!/bin/bash
# vibe-claude 启动脚本
SESSION_NAME="vibe-$(date +%s)"
tmux new-session -s "$SESSION_NAME" "claude $@"
```

**输出监控：**
```python
async def monitor_session(session_id: str):
    last_output = ""
    while True:
        result = subprocess.run(
            ["tmux", "capture-pane", "-t", session_id, "-p", "-S", "-500"],
            capture_output=True, text=True
        )
        current = result.stdout
        if current != last_output:
            diff = get_new_content(last_output, current)
            await broadcast_to_clients(session_id, diff)
            last_output = current
        await asyncio.sleep(0.5)
```

**发送指令：**
```python
def send_command(session_id: str, text: str):
    subprocess.run(["tmux", "send-keys", "-t", session_id, text])
    subprocess.run(["tmux", "send-keys", "-t", session_id, "Enter"])
```

---

## 5. 下一步

1. ✅ POC-A: tmux 输出捕获测试
2. ✅ POC-B: tmux 输入注入测试
3. ✅ POC-C: 完整交互验证
4. 🔜 开始后端开发（FastAPI + tmux 管理）
5. 🔜 实现 vibe-claude 包装脚本
6. 🔜 实现 WebSocket 实时推送
7. 🔜 实现前端 UI

---

## 6. 测试环境

- Claude Code CLI 版本：2.0.76
- 模型：claude-opus-4.5
- 操作系统：macOS Darwin 25.1.0
- tmux 版本：通过 Homebrew 安装

---

## 7. tmux 命令速查

```bash
# 会话管理
tmux new-session -d -s NAME "claude"   # 创建后台会话
tmux new-session -s NAME "claude"      # 创建并附加会话
tmux list-sessions                      # 列出所有会话
tmux attach -t NAME                     # 附加到会话
tmux kill-session -t NAME              # 结束会话

# 输出捕获
tmux capture-pane -t NAME -p           # 捕获当前屏幕
tmux capture-pane -t NAME -p -S -500   # 捕获最近 500 行
tmux capture-pane -t NAME -p -e        # 保留 ANSI 颜色

# 输入注入
tmux send-keys -t NAME "text" Enter    # 发送文本 + 回车
tmux send-keys -t NAME C-c             # 发送 Ctrl+C
tmux send-keys -t NAME Escape          # 发送 Escape
```
