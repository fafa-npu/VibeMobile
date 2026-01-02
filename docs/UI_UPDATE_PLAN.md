# VibeMobile Web UI 更新计划

基于 `docs/demos/demo-scheme-a-v2.html` 的设计方案，本文档详细描述如何将现有React组件更新为新的UI设计。

---

## 一、全局样式更新 (index.css)

### 1.1 CSS Variables 定义

需要在 `web/src/index.css` 中添加以下CSS变量：

```css
:root {
  /* 主背景 */
  --bg-primary: #f0f2f5;
  --bg-secondary: #ffffff;
  --bg-elevated: #ffffff;

  /* 终端区域 */
  --bg-terminal: #2d3748;
  --bg-terminal-light: #4a5568;

  /* 文字颜色 */
  --text-primary: #1a202c;
  --text-secondary: #718096;
  --text-muted: #a0aec0;
  --text-inverse: #ffffff;

  /* 主题色 - Claude橙色系 */
  --accent-primary: #d97706;
  --accent-primary-light: #fbbf24;
  --accent-primary-bg: rgba(217, 119, 6, 0.1);

  /* 功能色 */
  --accent-blue: #3b82f6;
  --accent-blue-light: #60a5fa;
  --accent-blue-bg: rgba(59, 130, 246, 0.1);

  --accent-green: #10b981;
  --accent-green-light: #34d399;
  --accent-green-bg: rgba(16, 185, 129, 0.1);

  --accent-purple: #8b5cf6;
  --accent-purple-light: #a78bfa;
  --accent-purple-bg: rgba(139, 92, 246, 0.1);

  --accent-red: #ef4444;
  --accent-red-bg: rgba(239, 68, 68, 0.1);

  /* 气泡颜色 */
  --bubble-user: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
  --bubble-claude: #ffffff;

  /* 边框和阴影 */
  --border-color: #e2e8f0;
  --border-light: #f1f5f9;
  --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
  --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);

  /* 安全区域 */
  --safe-area-top: env(safe-area-inset-top, 0px);
  --safe-area-bottom: env(safe-area-inset-bottom, 0px);
}
```

### 1.2 基础样式

```css
body {
  font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', sans-serif;
  background: var(--bg-primary);
  color: var(--text-primary);
  line-height: 1.5;
}
```

---

## 二、组件更新详情

### 2.1 Header 组件

**文件**: `web/src/components/Header.tsx` + `Header.module.css`

#### 结构变更

```tsx
<header className={styles.header}>
  <div className={styles.headerMain}>
    <button className={styles.backBtn}>←</button>
    <div className={styles.headerInfo}>
      <div className={styles.headerTitle}>
        {sessionName}
        <StatusBadge status={status} />
      </div>
      <div className={styles.headerSubtitle}>{projectPath}</div>
    </div>
    <div className={styles.headerActions}>
      <button className={styles.iconBtn}>⋯</button>
    </div>
  </div>
</header>
```

#### CSS 样式规格

| 元素 | 属性 | 值 |
|------|------|-----|
| `.header` | background | `var(--bg-secondary)` |
| `.header` | padding | `calc(var(--safe-area-top) + 12px) 16px 12px` |
| `.header` | border-bottom | `1px solid var(--border-color)` |
| `.backBtn` | size | 36x36px, border-radius: 10px |
| `.backBtn` | background | `var(--bg-primary)` |
| `.backBtn` | border | `1px solid var(--border-color)` |
| `.headerTitle` | font | 17px, font-weight: 600 |
| `.headerSubtitle` | font | 12px, color: `var(--text-secondary)` |

#### StatusBadge 子组件

```tsx
interface StatusBadgeProps {
  status: 'running' | 'thinking' | 'waiting' | 'ended';
}

// 样式规格
.statusBadge {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 4px 10px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 500;
}

.statusBadge.running {
  background: var(--accent-green-bg);
  color: var(--accent-green);
}

.statusBadge.thinking {
  background: var(--accent-primary-bg);
  color: var(--accent-primary);
}

.statusDot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: currentColor;
}

// thinking状态需要脉动动画
@keyframes pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.5; transform: scale(0.8); }
}
```

---

### 2.2 Tab Bar 组件 (新建)

**文件**: `web/src/components/TabBar.tsx` + `TabBar.module.css`

#### 结构

```tsx
interface TabBarProps {
  activeTab: 'terminal' | 'files';
  onTabChange: (tab: 'terminal' | 'files') => void;
}

<div className={styles.tabBar}>
  <button className={`${styles.tabBtn} ${activeTab === 'terminal' ? styles.active : ''}`}>
    💬 终端
  </button>
  <button className={`${styles.tabBtn} ${activeTab === 'files' ? styles.active : ''}`}>
    📁 文件
  </button>
</div>
```

#### CSS 样式规格

| 元素 | 属性 | 值 |
|------|------|-----|
| `.tabBar` | display | flex |
| `.tabBar` | padding | `0 16px` |
| `.tabBar` | background | `var(--bg-secondary)` |
| `.tabBar` | border-bottom | `1px solid var(--border-color)` |
| `.tabBtn` | flex | 1 |
| `.tabBtn` | padding | `12px 16px` |
| `.tabBtn` | border | none |
| `.tabBtn` | border-bottom | `2px solid transparent` |
| `.tabBtn` | background | transparent |
| `.tabBtn` | font-size | 14px, font-weight: 500 |
| `.tabBtn` | color | `var(--text-secondary)` |
| `.tabBtn.active` | color | `var(--accent-blue)` |
| `.tabBtn.active` | border-bottom-color | `var(--accent-blue)` |

---

### 2.3 Terminal 组件 (重构为 ChatContainer)

**文件**: `web/src/components/Terminal.tsx` + `Terminal.module.css`

#### 主容器

```tsx
<div className={styles.chatContainer}>
  {messages.map(msg => <Message key={msg.id} {...msg} />)}
</div>
```

```css
.chatContainer {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  -webkit-overflow-scrolling: touch;
  background: var(--bg-primary);
}
```

#### Message 组件

```tsx
type MessageType = 'user' | 'claude' | 'system' | 'tool' | 'thinking';

interface MessageProps {
  type: MessageType;
  content: string;
  timestamp?: string;
  toolData?: ToolCardData;
}
```

##### 用户消息样式

```css
.message {
  display: flex;
  flex-direction: column;
  max-width: 88%;
  animation: messageIn 0.3s ease;
}

.message.user {
  align-self: flex-end;
}

.messageLabel {
  font-size: 11px;
  color: var(--text-secondary);
  margin-bottom: 4px;
  padding: 0 12px;
  display: flex;
  align-items: center;
  gap: 6px;
}

.message.user .messageLabel {
  justify-content: flex-end;
}

.labelAvatar {
  width: 18px;
  height: 18px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 10px;
}

.labelAvatar.user {
  background: linear-gradient(135deg, var(--accent-blue) 0%, var(--accent-purple) 100%);
  color: white;
}

.bubble {
  padding: 12px 16px;
  border-radius: 20px;
  font-size: 15px;
  line-height: 1.5;
  word-break: break-word;
  box-shadow: var(--shadow-sm);
}

.message.user .bubble {
  background: var(--bubble-user);
  color: var(--text-inverse);
  border-bottom-right-radius: 6px;
}

.messageTime {
  font-size: 10px;
  color: var(--text-muted);
  margin-top: 4px;
  padding: 0 12px;
}

.message.user .messageTime {
  text-align: right;
}

@keyframes messageIn {
  from {
    opacity: 0;
    transform: translateY(12px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
```

##### Claude消息样式

```css
.message.claude {
  align-self: flex-start;
}

.labelAvatar.claude {
  background: linear-gradient(135deg, var(--accent-primary) 0%, var(--accent-primary-light) 100%);
  color: white;
}

.message.claude .bubble {
  background: var(--bubble-claude);
  color: var(--text-primary);
  border: 1px solid var(--border-color);
  border-bottom-left-radius: 6px;
}
```

##### 系统消息样式

```css
.message.system {
  align-self: center;
  max-width: 90%;
}

.systemMessage {
  background: var(--bg-secondary);
  border-radius: 20px;
  padding: 10px 20px;
  font-size: 13px;
  color: var(--text-secondary);
  text-align: center;
  border: 1px solid var(--border-color);
  box-shadow: var(--shadow-sm);
}

.systemMessage .highlight {
  color: var(--accent-blue);
  font-weight: 500;
}

.modelTag {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  background: var(--accent-primary-bg);
  color: var(--accent-primary);
  padding: 2px 8px;
  border-radius: 10px;
  font-size: 11px;
  font-weight: 600;
  margin-left: 4px;
}
```

---

### 2.4 ToolCard 组件 (新建)

**文件**: `web/src/components/ToolCard.tsx` + `ToolCard.module.css`

#### 结构

```tsx
interface ToolCardProps {
  type: 'read' | 'search' | 'write' | 'bash';
  name: string;
  description: string;
  status: 'running' | 'success' | 'failed';
  output?: string;
  resultCount?: string;
}

<div className={`${styles.toolCard} ${expanded ? styles.expanded : ''}`} onClick={toggleExpand}>
  <div className={styles.toolHeader}>
    <div className={`${styles.toolIcon} ${styles[type]}`}>
      {iconMap[type]}
    </div>
    <div className={styles.toolInfo}>
      <div className={styles.toolName}>{name}</div>
      <div className={styles.toolDesc}>{description}</div>
    </div>
    <div className={`${styles.toolStatus} ${styles[status]}`}>
      <span className={styles.statusIcon}>{status === 'success' ? '✓' : '...'}</span>
      <span>{statusText}</span>
    </div>
    <span className={styles.toolExpand}>▼</span>
  </div>
  {expanded && (
    <div className={styles.toolContent}>
      <pre className={styles.toolOutput}>{output}</pre>
    </div>
  )}
</div>
```

#### CSS 样式规格

| 元素 | 属性 | 值 |
|------|------|-----|
| `.toolCard` | background | `var(--bg-secondary)` |
| `.toolCard` | border-radius | 12px |
| `.toolHeader` | padding | 12px |
| `.toolIcon` | size | 36x36px, border-radius: 10px |
| `.toolIcon.read` | background | `var(--accent-blue-bg)` |
| `.toolIcon.search` | background | `var(--accent-purple-bg)` |
| `.toolIcon.write` | background | `var(--accent-green-bg)` |
| `.toolIcon.bash` | background | `var(--accent-primary-bg)` |
| `.toolName` | font | 13px, font-weight: 600 |
| `.toolDesc` | font | 11px, font-family: 'SF Mono', monospace |
| `.toolDesc` | color | `var(--text-muted)` |
| `.toolStatus.success` | color | `var(--accent-green)` |
| `.toolStatus.running` | color | `var(--accent-primary)` |
| `.toolOutput` | background | `var(--bg-terminal)` |
| `.toolOutput` | border-radius | 8px |
| `.toolOutput` | padding | `10px 12px` |
| `.toolOutput` | font | 11px, 'SF Mono', monospace |
| `.toolOutput` | color | #e2e8f0 |
| `.toolOutput` | max-height | 180px |

#### 图标映射

```tsx
const iconMap = {
  read: '📄',
  search: '🔍',
  write: '✏️',
  bash: '⚡'
};
```

---

### 2.5 ThinkingCard 组件 (新建)

**文件**: `web/src/components/ThinkingCard.tsx` + `ThinkingCard.module.css`

#### 结构

```tsx
interface ThinkingCardProps {
  title: string;
  description?: string;
  progress?: { current: number; total: number };
}

<div className={styles.thinkingCard}>
  <div className={styles.thinkingHeader}>
    <div className={styles.thinkingSpinner}></div>
    <div className={styles.thinkingContent}>
      <div className={styles.thinkingTitle}>{title}</div>
      {description && <div className={styles.thinkingDesc}>{description}</div>}
    </div>
  </div>
  {progress && (
    <div className={styles.thinkingProgress}>
      <div className={styles.progressBar}>
        <div className={styles.progressFill} style={{ width: `${(progress.current / progress.total) * 100}%` }}></div>
      </div>
      <span className={styles.progressText}>{progress.current}/{progress.total} 步骤</span>
    </div>
  )}
</div>
```

#### CSS 样式规格

```css
.thinkingCard {
  background: var(--bg-secondary);
  border-radius: 12px;
  padding: 12px;
}

.thinkingSpinner {
  width: 20px;
  height: 20px;
  border: 2px solid var(--border-color);
  border-top-color: var(--accent-primary);
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.thinkingTitle {
  font-size: 13px;
  font-weight: 600;
  color: var(--accent-primary);
}

.thinkingDesc {
  font-size: 11px;
  color: var(--text-muted);
  margin-top: 1px;
}

.progressBar {
  flex: 1;
  height: 4px;
  background: var(--bg-primary);
  border-radius: 2px;
  overflow: hidden;
}

.progressFill {
  height: 100%;
  background: var(--accent-primary);
  border-radius: 2px;
  animation: progressPulse 1.5s ease-in-out infinite;
}

@keyframes progressPulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

.progressText {
  font-size: 10px;
  color: var(--text-muted);
}
```

---

### 2.6 CommandInput 组件

**文件**: `web/src/components/CommandInput.tsx` + `CommandInput.module.css`

#### 结构变更

```tsx
<div className={styles.inputArea}>
  {/* Permission Mode Bar */}
  <div className={`${styles.permissionBar} ${styles[permissionMode]}`} onClick={cyclePermissionMode}>
    <div className={styles.permissionIndicator}>
      <span className={styles.permissionArrows}>▶▶</span>
      <span className={styles.permissionText}>{permissionText}</span>
    </div>
    <span className={styles.permissionHint}>(点击切换)</span>
  </div>

  {/* Quick Actions */}
  <div className={styles.quickActions}>
    <button className={`${styles.quickBtn} ${styles.danger}`} onClick={() => onSpecialKey('C-c')}>Ctrl+C</button>
    <button className={styles.quickBtn} onClick={() => onSpecialKey('Enter')}>Enter</button>
    <button className={styles.quickBtn} onClick={() => onSpecialKey('Escape')}>Esc</button>
    <button className={styles.quickBtn} onClick={() => onSpecialKey('Up')}>↑</button>
    <button className={styles.quickBtn} onClick={() => onSpecialKey('Down')}>↓</button>
  </div>

  {/* Input Row */}
  <div className={styles.inputRow}>
    <button className={styles.attachmentBtn} onClick={handleUploadClick}>
      <span className={styles.attachmentIcon}>📎</span>
      <span className={styles.attachmentPlus}>+</span>
    </button>
    <div className={styles.inputWrapper}>
      <textarea
        ref={textareaRef}
        className={styles.messageInput}
        value={value}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder="Message..."
        rows={1}
      />
    </div>
    <button className={styles.sendBtn} onClick={handleSend}>
      ↑
    </button>
  </div>
</div>
```

#### Permission Mode 状态

```tsx
const permissionModes = [
  { key: 'bypass', text: 'bypass permissions on', class: '' },
  { key: 'caution', text: 'auto-accept edits', class: 'caution' },
  { key: 'restricted', text: 'normal mode', class: 'restricted' }
];
```

#### CSS 样式规格

```css
.inputArea {
  background: var(--bg-secondary);
  border-top: 1px solid var(--border-color);
  padding: 10px 16px calc(var(--safe-area-bottom) + 10px);
}

/* Permission Bar */
.permissionBar {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin-bottom: 10px;
  padding: 8px 14px;
  background: var(--bg-primary);
  border-radius: 8px;
  cursor: pointer;
}

.permissionArrows {
  font-size: 10px;
  font-weight: 700;
  color: var(--accent-green);
}

.permissionBar.caution .permissionArrows {
  color: var(--accent-primary);
}

.permissionBar.restricted .permissionArrows {
  color: var(--accent-red);
}

.permissionText {
  font-size: 12px;
  font-weight: 500;
  color: var(--accent-green);
  font-family: 'SF Mono', monospace;
}

.permissionBar.caution .permissionText {
  color: var(--accent-primary);
}

.permissionBar.restricted .permissionText {
  color: var(--accent-red);
}

.permissionHint {
  font-size: 10px;
  color: var(--text-muted);
}

/* Quick Actions */
.quickActions {
  display: flex;
  gap: 6px;
  margin-bottom: 10px;
}

.quickBtn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 8px 6px;
  border-radius: 8px;
  border: none;
  background: var(--bg-primary);
  font-size: 12px;
  font-family: 'SF Mono', monospace;
  font-weight: 500;
  color: var(--text-secondary);
  cursor: pointer;
}

.quickBtn:active {
  background: var(--border-color);
}

.quickBtn.danger {
  color: var(--accent-red);
}

/* Input Row */
.inputRow {
  display: flex;
  align-items: flex-end;
  gap: 8px;
}

/* Attachment Button */
.attachmentBtn {
  width: 44px;
  height: 44px;
  border-radius: 22px;
  background: var(--bg-primary);
  border: none;
  position: relative;
  flex-shrink: 0;
}

.attachmentIcon {
  font-size: 20px;
  color: var(--accent-purple);
}

.attachmentPlus {
  position: absolute;
  bottom: 0;
  right: 0;
  width: 16px;
  height: 16px;
  border-radius: 50%;
  background: var(--accent-purple);
  color: white;
  font-size: 12px;
  font-weight: 700;
}

/* Input Wrapper */
.inputWrapper {
  flex: 1;
  background: var(--bg-primary);
  border-radius: 22px;
  padding: 10px 16px;
}

.messageInput {
  width: 100%;
  border: none;
  background: transparent;
  font-size: 16px;
  line-height: 1.4;
  resize: none;
  max-height: 120px;
  outline: none;
}

.messageInput::placeholder {
  color: var(--text-muted);
}

/* Send Button */
.sendBtn {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  background: var(--accent-blue);
  color: white;
  border: none;
  font-size: 18px;
  font-weight: 600;
  flex-shrink: 0;
}

.sendBtn:active {
  opacity: 0.8;
}
```

---

## 三、文件修改清单

| 序号 | 文件路径 | 操作 | 说明 |
|------|----------|------|------|
| 1 | `web/src/index.css` | 修改 | 添加CSS变量和基础样式 |
| 2 | `web/src/components/Header.tsx` | 修改 | 重构Header结构,添加StatusBadge |
| 3 | `web/src/components/Header.module.css` | 重写 | 完全按照新设计重写样式 |
| 4 | `web/src/components/TabBar.tsx` | 新建 | Tab切换组件 |
| 5 | `web/src/components/TabBar.module.css` | 新建 | Tab组件样式 |
| 6 | `web/src/components/Terminal.tsx` | 修改 | 重构为聊天气泡布局 |
| 7 | `web/src/components/Terminal.module.css` | 重写 | 消息气泡和容器样式 |
| 8 | `web/src/components/ToolCard.tsx` | 新建 | 工具执行卡片组件 |
| 9 | `web/src/components/ToolCard.module.css` | 新建 | 工具卡片样式 |
| 10 | `web/src/components/ThinkingCard.tsx` | 新建 | 思考状态卡片组件 |
| 11 | `web/src/components/ThinkingCard.module.css` | 新建 | 思考卡片样式 |
| 12 | `web/src/components/CommandInput.tsx` | 修改 | 重构输入区域布局 |
| 13 | `web/src/components/CommandInput.module.css` | 重写 | 完全按照新设计重写样式 |
| 14 | `web/src/pages/SessionDetail.tsx` | 修改 | 集成TabBar和新组件 |
| 15 | `web/src/pages/SessionDetail.module.css` | 修改 | 页面布局调整 |

---

## 四、实施顺序

### Phase 1: 基础设施 (优先级: 高)
1. 更新 `index.css` 添加CSS变量
2. 创建 `TabBar` 组件

### Phase 2: 核心显示组件 (优先级: 高)
3. 重构 `Header` 组件
4. 重构 `Terminal` 组件为聊天布局
5. 创建 `ToolCard` 组件
6. 创建 `ThinkingCard` 组件

### Phase 3: 输入区域 (优先级: 高)
7. 重构 `CommandInput` 组件

### Phase 4: 页面整合 (优先级: 中)
8. 更新 `SessionDetail` 页面集成所有组件

---

## 五、设计要点备忘

### 5.1 关键UI元素清单

- [x] Header with back button and status badge
- [x] Tab bar with underline style (终端/文件)
- [x] Chat container with message bubbles
- [x] User messages (right-aligned, blue gradient)
- [x] Claude messages (left-aligned, white with border)
- [x] System messages (centered, rounded pill)
- [x] Tool cards (collapsible, icon-based)
- [x] Thinking card (spinner + progress bar)
- [x] Permission mode bar (green/orange/red cycling)
- [x] Quick action buttons (Ctrl+C, Enter, Esc, ↑, ↓)
- [x] Attachment button with + badge
- [x] Text input (rounded, auto-resize)
- [x] Send button (blue circle with ↑)

### 5.2 字体规格

- 正文: -apple-system, BlinkMacSystemFont, 'SF Pro Text'
- 代码/等宽: 'SF Mono', 'Menlo', monospace

### 5.3 动画规格

- `messageIn`: 0.3s ease, translateY(12px) → translateY(0)
- `pulse`: 1.5s ease-in-out infinite, opacity + scale
- `spin`: 1s linear infinite, rotate(360deg)
- `progressPulse`: 1.5s ease-in-out infinite, opacity

---

*文档版本: 1.0*
*创建日期: 2026-01-02*
*基于: demo-scheme-a-v2.html*
