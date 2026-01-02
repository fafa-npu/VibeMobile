// ThinkingCard component for displaying thinking/processing state

import styles from './ThinkingCard.module.css';

interface ThinkingCardProps {
  title: string;
  description?: string;
  progress?: {
    current: number;
    total: number;
  };
}

export function ThinkingCard({ title, description, progress }: ThinkingCardProps) {
  return (
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
            <div
              className={styles.progressFill}
              style={{ width: `${(progress.current / progress.total) * 100}%` }}
            ></div>
          </div>
          <span className={styles.progressText}>
            {progress.current}/{progress.total} 步骤
          </span>
        </div>
      )}
    </div>
  );
}
