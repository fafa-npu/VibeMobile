# Node.js 后端迁移测试方案

## 测试目标
验证从 Python (FastAPI) 迁移到 Node.js (Express) 后，所有功能正常工作。

## 测试环境准备

```bash
cd /Users/zhaohua/Documents/repos/VibeMobile/web
npm install
```

---

## 第一阶段：基础服务测试

### 1.1 服务器启动测试
- [ ] 开发模式启动 (`npx tsx server/index.ts`)
- [ ] 生产构建 (`node scripts/build-server.js`)
- [ ] 生产模式启动 (`node dist/server.cjs`)
- [ ] 健康检查端点 (`/health`)

### 1.2 API 端点可用性测试
- [ ] GET /health
- [ ] GET /api/sessions
- [ ] GET /api/auth/status
- [ ] GET /api/notifications/types

---

## 第二阶段：核心功能测试

### 2.1 Session 管理 API

| 测试用例 | 端点 | 预期结果 |
|---------|------|---------|
| 列出会话 | GET /api/sessions | 返回 tmux 会话列表 |
| 获取单个会话 | GET /api/sessions/:id | 返回会话详情或 404 |
| 获取会话输出 | GET /api/sessions/:id/output | 返回 tmux 输出 |
| 创建会话 | POST /api/sessions | 创建新 tmux 会话 |
| 发送命令 | POST /api/sessions/:id/send | 发送文本到会话 |
| 发送特殊键 | POST /api/sessions/:id/key | 发送 Ctrl+C 等 |
| 删除会话 | DELETE /api/sessions/:id | 终止 tmux 会话 |

### 2.2 认证 API

| 测试用例 | 端点 | 预期结果 |
|---------|------|---------|
| 生成配对码 | POST /api/auth/pair/initiate | 返回 6 位配对码 |
| 配对码验证 | 内部验证 | 5分钟过期，不可重复使用 |
| 刷新令牌 | POST /api/auth/refresh | 返回新的 access_token |
| 登出 | POST /api/auth/logout | 清除 cookie |
| 认证状态 | GET /api/auth/status | 返回认证信息 |
| 设备列表 | GET /api/auth/devices | 返回已注册设备 |

### 2.3 WebSocket 功能

| 测试用例 | 预期结果 |
|---------|---------|
| WebSocket 连接 | 收到 `connected` 消息 |
| 订阅会话 | 收到 `subscribed` 确认 |
| 会话输出推送 | 实时收到 `session.output` |
| Ping/Pong | 心跳保持连接 |

---

## 第三阶段：集成测试

### 3.1 Desktop App 集成
- [ ] Desktop App 能启动 Node.js 服务器
- [ ] 健康检查通过
- [ ] 会话列表正常显示
- [ ] 状态卡显示正确

### 3.2 Web UI 集成
- [ ] 访问 Web UI 页面
- [ ] 会话列表加载
- [ ] 实时输出更新

---

## 测试脚本

### test-api.sh
```bash
#!/bin/bash
# 基础 API 测试脚本

BASE_URL="http://localhost:8765"

echo "=== 健康检查 ==="
curl -s "$BASE_URL/health" | jq .

echo -e "\n=== 会话列表 ==="
curl -s "$BASE_URL/api/sessions" | jq .

echo -e "\n=== 认证状态 ==="
curl -s "$BASE_URL/api/auth/status" | jq .

echo -e "\n=== 通知类型 ==="
curl -s "$BASE_URL/api/notifications/types" | jq .
```

### test-websocket.js
```javascript
const WebSocket = require('ws');

const ws = new WebSocket('ws://localhost:8765/ws');

ws.on('open', () => {
  console.log('Connected');

  // 订阅会话
  ws.send(JSON.stringify({
    type: 'subscribe',
    data: { sessionIds: ['vibe-1'] }
  }));

  // Ping
  ws.send(JSON.stringify({ type: 'ping' }));
});

ws.on('message', (data) => {
  console.log('Received:', JSON.parse(data));
});

ws.on('close', () => console.log('Disconnected'));
ws.on('error', (err) => console.error('Error:', err));

// 10秒后关闭
setTimeout(() => ws.close(), 10000);
```

---

## 验收标准

1. **功能完整性**: 所有 Python 后端的功能在 Node.js 中都能正常工作
2. **API 兼容性**: API 响应格式与原版一致，前端无需修改
3. **性能**: 响应时间 < 100ms
4. **稳定性**: 服务器可以持续运行，无内存泄漏
5. **错误处理**: 适当的错误响应和日志记录
