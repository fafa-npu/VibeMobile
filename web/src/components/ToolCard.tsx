// ToolCard component for displaying tool execution status

import { useState } from 'react';
import styles from './ToolCard.module.css';

export type ToolType = 'read' | 'search' | 'write' | 'bash' | 'edit' | 'glob' | 'grep';
export type ToolStatus = 'running' | 'success' | 'failed';

interface ToolCardProps {
  type: ToolType;
  name: string;
  description: string;
  status: ToolStatus;
  output?: string;
  resultCount?: string;
  defaultExpanded?: boolean;
}

const ICON_MAP: Record<ToolType, string> = {
  read: '📄',
  search: '🔍',
  write: '✏️',
  bash: '⚡',
  edit: '✏️',
  glob: '🔍',
  grep: '🔍',
};

const TYPE_CLASS_MAP: Record<ToolType, string> = {
  read: 'read',
  search: 'search',
  write: 'write',
  bash: 'bash',
  edit: 'write',
  glob: 'search',
  grep: 'search',
};

export function ToolCard({
  type,
  name,
  description,
  status,
  output,
  resultCount,
  defaultExpanded = false,
}: ToolCardProps) {
  const [expanded, setExpanded] = useState(defaultExpanded);

  const icon = ICON_MAP[type] || '🔧';
  const typeClass = TYPE_CLASS_MAP[type] || 'bash';

  const statusText = status === 'success'
    ? (resultCount || '完成')
    : status === 'failed'
    ? '失败'
    : '执行中...';

  const statusIcon = status === 'success'
    ? '✓'
    : status === 'failed'
    ? '✗'
    : '...';

  return (
    <div
      className={`${styles.toolCard} ${expanded ? styles.expanded : ''}`}
      onClick={() => setExpanded(!expanded)}
    >
      <div className={styles.toolHeader}>
        <div className={`${styles.toolIcon} ${styles[typeClass]}`}>
          {icon}
        </div>
        <div className={styles.toolInfo}>
          <div className={styles.toolName}>{name}</div>
          <div className={styles.toolDesc}>{description}</div>
        </div>
        <div className={`${styles.toolStatus} ${styles[status]}`}>
          <span className={styles.statusIcon}>{statusIcon}</span>
          <span>{statusText}</span>
        </div>
        <span className={styles.toolExpand}>▼</span>
      </div>
      {expanded && output && (
        <div className={styles.toolContent}>
          <pre className={styles.toolOutput}>{output}</pre>
        </div>
      )}
    </div>
  );
}
