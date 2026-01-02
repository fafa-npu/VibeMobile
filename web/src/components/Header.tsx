// Header component with status badge

import styles from './Header.module.css';

export type SessionStatus = 'running' | 'thinking' | 'waiting' | 'ended';

interface HeaderProps {
  title: string;
  subtitle?: string;
  showBack?: boolean;
  onBack?: () => void;
  rightElement?: React.ReactNode;
  status?: SessionStatus;
}

function StatusBadge({ status }: { status: SessionStatus }) {
  const statusConfig = {
    running: { label: '运行中', className: styles.running },
    thinking: { label: '思考中', className: styles.thinking },
    waiting: { label: '等待中', className: styles.waiting },
    ended: { label: '已结束', className: styles.ended },
  };

  const config = statusConfig[status];

  return (
    <span className={`${styles.statusBadge} ${config.className}`}>
      <span className={styles.statusDot}></span>
      {config.label}
    </span>
  );
}

export function Header({
  title,
  subtitle,
  showBack,
  onBack,
  rightElement,
  status,
}: HeaderProps) {
  return (
    <header className={styles.header}>
      <div className={styles.headerMain}>
        {showBack ? (
          <button className={styles.backBtn} onClick={onBack}>
            ←
          </button>
        ) : (
          <div className={styles.logo}>V</div>
        )}

        <div className={styles.headerInfo}>
          <div className={styles.headerTitle}>
            {title}
            {status && <StatusBadge status={status} />}
          </div>
          {subtitle && <div className={styles.headerSubtitle}>{subtitle}</div>}
        </div>

        <div className={styles.headerActions}>
          {rightElement || <button className={styles.iconBtn}>⋯</button>}
        </div>
      </div>
    </header>
  );
}
