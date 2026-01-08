// Command input component with permission mode, quick actions, and voice input (Scheme A)
// Voice input uses toggle mode: click to start/stop, results go to input box

import { useState, useRef, useEffect, useCallback } from 'react';
import styles from './CommandInput.module.css';
import { useVoiceInput } from '../hooks/useVoiceInput';

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

const PERMISSION_MODES: { key: PermissionMode; text: string; icon: string }[] = [
  { key: 'bypass', text: 'bypass permissions on', icon: '▶▶' },
  { key: 'caution', text: 'auto-accept edits', icon: '▶' },
  { key: 'restricted', text: 'normal mode', icon: '⏸' },
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

  // Voice input hook - results go to input box instead of sending directly
  const {
    state: voiceState,
    isSupported: isVoiceSupported,
    interimTranscript,
    finalTranscript,
    startRecording,
    stopRecording,
    clearTranscript,
  } = useVoiceInput({
    lang: 'zh-CN',
    onResult: (transcript) => {
      // Insert transcript into input box instead of sending
      if (transcript.trim()) {
        setValue(prev => prev + transcript.trim());
        // Focus the textarea after inserting text
        textareaRef.current?.focus();
      }
    },
    onError: (error) => {
      console.error('Voice input error:', error);
    },
  });

  // Current interim transcript to display above input
  const showInterim = voiceState === 'recording' && (interimTranscript || finalTranscript);
  const interimDisplay = finalTranscript + interimTranscript || '正在聆听...';

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

  // Toggle voice recording (Scheme A: click to start/stop)
  const toggleVoiceRecording = useCallback(() => {
    if (!isVoiceSupported) {
      alert('当前浏览器不支持语音输入功能');
      return;
    }

    if (voiceState === 'recording') {
      stopRecording();
    } else {
      clearTranscript();
      startRecording();
    }
  }, [isVoiceSupported, voiceState, startRecording, stopRecording, clearTranscript]);

  const isRecording = voiceState === 'recording';

  const currentMode = PERMISSION_MODES.find(m => m.key === permissionMode);
  const currentModeText = currentMode?.text || '';
  const currentModeIcon = currentMode?.icon || '▶▶';

  return (
    <div className={styles.inputArea}>
      {/* Status Bar */}
      <div className={styles.statusBar}>
        <div className={styles.statusLeft}>
          <div
            className={`${styles.permissionIndicator} ${styles[permissionMode]}`}
            onClick={cyclePermissionMode}
          >
            <span className={styles.permissionIcon}>{currentModeIcon}</span>
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

        {/* Voice Button (Scheme A: toggle mode) */}
        <button
          className={`${styles.voiceBtn} ${isRecording ? styles.recording : ''}`}
          onClick={toggleVoiceRecording}
          disabled={disabled}
          title={isRecording ? '停止录音' : '开始语音输入'}
        >
          {isRecording ? '⏹' : '🎤'}
        </button>

        {/* Input Wrapper with interim text bubble */}
        <div className={styles.inputWrapper}>
          {/* Interim text bubble - shows during recording */}
          {showInterim && (
            <div className={styles.interimText}>
              {interimDisplay}
            </div>
          )}
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
