// Session card component - Scheme B style

import type { Session } from '../types';
import { useTimeAgo } from '../hooks';
import styles from './SessionCard.module.css';

interface SessionCardProps {
  session: Session;
  onClick: () => void;
}

// Filter out TUI/box-drawing lines and system prompts
function filterOutputLines(text: string): string[] {
  return text
    .split('\n')
    .filter((line) => {
      const trimmed = line.trim();
      if (!trimmed) return false;
      // Skip box drawing lines
      if (/^[│├┤┃╭╮╰╯┏┓┗┛┌┐└┘]/.test(trimmed)) return false;
      if (/[│├┤┃╭╮╰╯┏┓┗┛┌┐└┘]$/.test(trimmed)) return false;
      // Skip separator lines
      if (/^[_─━\-=]+$/.test(trimmed) && trimmed.length >= 10) return false;
      // Skip lines with box sides
      if (/^│.*│$/.test(trimmed)) return false;

      // Skip system prompts and UI hints
      // Lines starting with special UI characters
      if (/^[?⏵▶►]\s/.test(trimmed)) return false;
      // Lines containing keyboard shortcut hints or mode indicators
      if (/\b(for shortcuts?|permissions? on|mode$|shift\+tab|to cycle)/i.test(trimmed)) return false;
      // Slash command hints (not executed commands)
      if (/^\/\w+\s+to\s+/i.test(trimmed)) return false;

      // Skip prompt lines that only contain system UI elements
      if (/^[>❯]\s*[?⏵▶►]/.test(trimmed)) return false;
      if (/^[>❯]\s*$/.test(trimmed)) return false;

      return true;
    });
}

// Get line type for styling
function getLineType(line: string): string {
  if (line.startsWith('>') || line.startsWith('❯')) return styles.input || '';
  if (line.startsWith('⏺') || line.startsWith('●')) return styles.response || '';
  if (line.includes('✓') || line.includes('成功')) return styles.success || '';
  return '';
}

export function SessionCard({ session, onClick }: SessionCardProps) {
  const timeAgo = useTimeAgo(session.updated_at);
  const isEnded = session.status === 'ended';

  // Extract last non-empty lines for preview, filtering TUI elements
  const previewLines = filterOutputLines(session.output_tail).slice(-3);

  return (
    <div className={`${styles.card} ${isEnded ? styles.ended : ''}`} onClick={onClick}>
      <div className={styles.header}>
        <div>
          <div className={styles.sessionIcon}>💻</div>
          <div className={styles.name}>{session.session_id}</div>
          <div className={styles.path}>
            <span className="truncate">
              {session.project_path || '~/'}
            </span>
          </div>
        </div>
        <span
          className={`${styles.status} ${isEnded ? styles.ended : styles.active}`}
        >
          {isEnded ? '已结束' : '运行中'}
        </span>
      </div>

      {previewLines.length > 0 && (
        <div className={styles.preview}>
          {previewLines.map((line, i) => (
            <div key={i} className={`${styles.previewLine} ${getLineType(line)}`}>
              {line}
            </div>
          ))}
        </div>
      )}

      <div className={styles.meta}>
        <span>{timeAgo}</span>
        <span>Claude Opus 4.5</span>
      </div>
    </div>
  );
}
