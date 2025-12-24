// Header component

import styles from './Header.module.css';

interface HeaderProps {
  title: string;
  subtitle?: string;
  showBack?: boolean;
  onBack?: () => void;
  rightElement?: React.ReactNode;
  status?: 'connected' | 'connecting' | 'disconnected';
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
      <div className={styles.left}>
        {showBack ? (
          <button className={styles.backBtn} onClick={onBack}>
            ←
          </button>
        ) : (
          <div className={styles.logo}>V</div>
        )}
      </div>

      <div className={styles.center}>
        <h1 className={styles.title}>{title}</h1>
        {subtitle && <div className={styles.subtitle}>{subtitle}</div>}
        {status && (
          <div className={styles.status}>
            <span
              className={`${styles.statusDot} ${styles[status]}`}
            />
            <span>
              {status === 'connected'
                ? '已连接'
                : status === 'connecting'
                ? '连接中...'
                : '已断开'}
            </span>
          </div>
        )}
      </div>

      <div className={styles.right}>{rightElement}</div>
    </header>
  );
}
