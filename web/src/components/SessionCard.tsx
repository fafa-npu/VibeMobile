// Session card component

import type { Session } from '../types';
import { useTimeAgo } from '../hooks';
import styles from './SessionCard.module.css';

interface SessionCardProps {
  session: Session;
  onClick: () => void;
}

// Filter out TUI/box-drawing lines
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
      return true;
    });
}

export function SessionCard({ session, onClick }: SessionCardProps) {
  const timeAgo = useTimeAgo(session.updated_at);

  // Extract last non-empty lines for preview, filtering TUI elements
  const previewLines = filterOutputLines(session.output_tail).slice(-3);

  return (
    <div className={styles.card} onClick={onClick}>
      <div className={styles.header}>
        <span className={styles.name}>{session.session_id}</span>
        <span
          className={`${styles.status} ${
            session.status === 'ended' ? styles.ended : styles.active
          }`}
        >
          {session.status === 'ended' ? '已结束' : '运行中'}
        </span>
      </div>

      <div className={styles.path}>
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
        >
          <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" />
        </svg>
        <span className="truncate">
          {session.project_path || '~/'}
        </span>
      </div>

      {previewLines.length > 0 && (
        <div className={styles.preview}>
          {previewLines.map((line, i) => (
            <div key={i} className={styles.previewLine}>
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
