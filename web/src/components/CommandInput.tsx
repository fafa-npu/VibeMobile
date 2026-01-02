// Command input component with permission mode and quick actions

import { useState, useRef, useEffect } from 'react';
import styles from './CommandInput.module.css';

interface CommandInputProps {
  onSend: (content: string) => void;
  onSpecialKey?: (key: string) => void;
  onUpload?: (file: File) => void;
  disabled?: boolean;
  placeholder?: string;
  backgroundTasks?: number;
  tokenCount?: string;
}

type PermissionMode = 'bypass' | 'caution' | 'restricted';

const PERMISSION_MODES: { key: PermissionMode; text: string }[] = [
  { key: 'bypass', text: 'bypass permissions on' },
  { key: 'caution', text: 'auto-accept edits' },
  { key: 'restricted', text: 'normal mode' },
];

const QUICK_ACTIONS = [
  { label: 'Ctrl+C', key: 'C-c', danger: true },
  { label: 'Enter', key: 'Enter' },
  { label: 'Esc', key: 'Escape' },
  { label: '↑', key: 'Up' },
  { label: '↓', key: 'Down' },
];

export function CommandInput({
  onSend,
  onSpecialKey,
  onUpload,
  disabled = false,
  placeholder = 'Message...',
  backgroundTasks = 0,
  tokenCount = '',
}: CommandInputProps) {
  const [value, setValue] = useState('');
  const [permissionMode, setPermissionMode] = useState<PermissionMode>('bypass');
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Auto-resize textarea
  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = `${Math.min(textareaRef.current.scrollHeight, 120)}px`;
    }
  }, [value]);

  const handleSend = () => {
    if (!value.trim() || disabled) return;
    onSend(value.trim());
    setValue('');
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const handleQuickAction = (key: string) => {
    onSpecialKey?.(key);
  };

  const cyclePermissionMode = () => {
    const currentIndex = PERMISSION_MODES.findIndex(m => m.key === permissionMode);
    const nextIndex = (currentIndex + 1) % PERMISSION_MODES.length;
    setPermissionMode(PERMISSION_MODES[nextIndex].key);
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file && onUpload) {
      onUpload(file);
    }
    e.target.value = '';
  };

  const handleUploadClick = () => {
    fileInputRef.current?.click();
  };

  const currentModeText = PERMISSION_MODES.find(m => m.key === permissionMode)?.text || '';

  return (
    <div className={styles.inputArea}>
      {/* Status Bar - 从终端底部提取的状态信息 */}
      <div className={styles.statusBar}>
        <div className={styles.statusLeft}>
          <div
            className={`${styles.permissionIndicator} ${styles[permissionMode]}`}
            onClick={cyclePermissionMode}
          >
            <span className={styles.permissionIcon}>▶▶</span>
            <span className={styles.permissionText}>{currentModeText}</span>
            <span className={styles.permissionHint}>(点击切换)</span>
          </div>
        </div>
        <div className={styles.statusRight}>
          {backgroundTasks > 0 && (
            <span className={styles.backgroundTasks}>{backgroundTasks} 后台任务</span>
          )}
          {tokenCount && (
            <span className={styles.tokenCount}>↑ {tokenCount}</span>
          )}
        </div>
      </div>

      {/* Quick Actions */}
      <div className={styles.quickActions}>
        {QUICK_ACTIONS.map((action) => (
          <button
            key={action.key}
            className={`${styles.quickBtn} ${action.danger ? styles.danger : ''}`}
            onClick={() => handleQuickAction(action.key)}
            disabled={disabled}
          >
            {action.label}
          </button>
        ))}
      </div>

      {/* Input Row */}
      <div className={styles.inputRow}>
        {/* Hidden file input */}
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          onChange={handleFileChange}
          style={{ display: 'none' }}
        />

        {/* Attachment Button */}
        <button
          className={styles.attachmentBtn}
          onClick={handleUploadClick}
          disabled={disabled}
          title="Upload"
        >
          <span className={styles.attachmentIcon}>📎</span>
          <span className={styles.attachmentPlus}>+</span>
        </button>

        {/* Text Input */}
        <div className={styles.inputWrapper}>
          <textarea
            ref={textareaRef}
            className={styles.messageInput}
            value={value}
            onChange={(e) => setValue(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={placeholder}
            disabled={disabled}
            rows={1}
          />
        </div>

        {/* Send Button */}
        <button
          className={styles.sendBtn}
          onClick={handleSend}
          disabled={disabled || !value.trim()}
        >
          ↑
        </button>
      </div>
    </div>
  );
}
