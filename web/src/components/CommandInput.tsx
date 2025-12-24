// Command input component

import { useState, useRef, useEffect } from 'react';
import styles from './CommandInput.module.css';

interface CommandInputProps {
  onSend: (content: string) => void;
  onSpecialKey?: (key: string) => void;
  disabled?: boolean;
  placeholder?: string;
}

interface QuickAction {
  label: string;
  value?: string;
  key?: string;
}

const QUICK_ACTIONS: QuickAction[] = [
  { label: '继续', value: '继续' },
  { label: '运行测试', value: '运行测试' },
  { label: '提交代码', value: 'git add . && git commit' },
  { label: '撤销', value: '撤销最近的修改' },
  { label: 'Ctrl+C', key: 'C-c' },
];

export function CommandInput({
  onSend,
  onSpecialKey,
  disabled = false,
  placeholder = '输入指令...',
}: CommandInputProps) {
  const [value, setValue] = useState('');
  const textareaRef = useRef<HTMLTextAreaElement>(null);

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

  const handleQuickAction = (action: QuickAction) => {
    if (action.key) {
      onSpecialKey?.(action.key);
    } else if (action.value) {
      onSend(action.value);
    }
  };

  return (
    <div className={`${styles.container} safe-area-bottom`}>
      <div className={styles.quickActions}>
        {QUICK_ACTIONS.map((action) => (
          <button
            key={action.label}
            className={styles.quickAction}
            onClick={() => handleQuickAction(action)}
            disabled={disabled}
          >
            {action.label}
          </button>
        ))}
      </div>

      <div className={styles.inputRow}>
        <div className={styles.inputWrapper}>
          <textarea
            ref={textareaRef}
            className={styles.input}
            value={value}
            onChange={(e) => setValue(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={placeholder}
            disabled={disabled}
            rows={1}
          />
        </div>
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
