// Command input component

import { useState, useRef, useEffect } from 'react';
import styles from './CommandInput.module.css';

interface CommandInputProps {
  onSend: (content: string) => void;
  onSpecialKey?: (key: string) => void;
  onUpload?: (file: File) => void;
  disabled?: boolean;
  placeholder?: string;
}

interface QuickAction {
  label: string;
  value?: string;
  key?: string;
}

interface ControlKey {
  label: string;
  key: string;
  className?: string;
}

const QUICK_ACTIONS: QuickAction[] = [
  { label: 'Ctrl+C', key: 'C-c' },
];

// Navigation control keys for menu selection
const NAV_KEYS: ControlKey[] = [
  { label: '↑', key: 'Up', className: styles.navUp },
  { label: '←', key: 'Left', className: styles.navLeft },
  { label: '↓', key: 'Down', className: styles.navDown },
  { label: '→', key: 'Right', className: styles.navRight },
];

// Special function keys
const SPECIAL_KEYS: ControlKey[] = [
  { label: 'Esc', key: 'Escape' },
  { label: 'Tab', key: 'Tab' },
  { label: '⏎', key: 'Enter' },
  { label: '模式', key: 'BTab' },  // shift+tab for auto-accept/bypass permission mode
];

export function CommandInput({
  onSend,
  onSpecialKey,
  onUpload,
  disabled = false,
  placeholder = '输入指令...',
}: CommandInputProps) {
  const [value, setValue] = useState('');
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

  const handleQuickAction = (action: QuickAction) => {
    if (action.key) {
      onSpecialKey?.(action.key);
    } else if (action.value) {
      onSend(action.value);
    }
  };

  const handleControlKey = async (key: string) => {
    // Handle key sequences (e.g., "Escape Escape" for mode switch)
    if (key.includes(' ')) {
      const keys = key.split(' ');
      for (const k of keys) {
        onSpecialKey?.(k);
        // Small delay between keys
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    } else {
      onSpecialKey?.(key);
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file && onUpload) {
      onUpload(file);
    }
    // Reset input so same file can be selected again
    e.target.value = '';
  };

  const handleUploadClick = () => {
    fileInputRef.current?.click();
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

      {/* Navigation and special keys control area */}
      <div className={styles.controlArea}>
        {/* Arrow keys in cross layout */}
        <div className={styles.navPad}>
          {NAV_KEYS.map((navKey) => (
            <button
              key={navKey.key}
              className={`${styles.navKey} ${navKey.className || ''}`}
              onClick={() => handleControlKey(navKey.key)}
              disabled={disabled}
            >
              {navKey.label}
            </button>
          ))}
        </div>

        {/* Special keys */}
        <div className={styles.specialKeys}>
          {SPECIAL_KEYS.map((specialKey) => (
            <button
              key={specialKey.key}
              className={styles.specialKey}
              onClick={() => handleControlKey(specialKey.key)}
              disabled={disabled}
            >
              {specialKey.label}
            </button>
          ))}
        </div>
      </div>

      <div className={styles.inputRow}>
        {/* Hidden file input for image upload */}
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          onChange={handleFileChange}
          style={{ display: 'none' }}
        />

        {/* Upload button */}
        <button
          className={styles.uploadBtn}
          onClick={handleUploadClick}
          disabled={disabled}
          title="上传图片"
        >
          <svg
            width="20"
            height="20"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
          >
            <path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48" />
          </svg>
        </button>

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
