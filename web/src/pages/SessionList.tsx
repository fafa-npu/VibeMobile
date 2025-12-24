// Session list page

import { useSessions, useWebSocket } from '../hooks';
import { useAppStore } from '../stores/appStore';
import { Header } from '../components/Header';
import { SessionCard } from '../components/SessionCard';
import styles from './SessionList.module.css';

export function SessionList() {
  const { data: sessions, isLoading, error } = useSessions();
  const { status } = useWebSocket();
  const setCurrentSessionId = useAppStore((s) => s.setCurrentSessionId);

  // All non-ended sessions are "running"
  const runningSessions = sessions?.filter((s) => s.status !== 'ended') || [];

  return (
    <div className={styles.container}>
      <Header
        title="VibeMobile"
        status={status}
      />

      <div className={styles.content}>
        {isLoading && (
          <div className={styles.loading}>
            <div className={styles.spinner} />
            <span>加载中...</span>
          </div>
        )}

        {error && (
          <div className={styles.error}>
            <span>连接失败</span>
            <p>无法连接到 VibeMobile 服务</p>
            <button onClick={() => window.location.reload()}>重试</button>
          </div>
        )}

        {!isLoading && !error && sessions?.length === 0 && (
          <div className={styles.empty}>
            <div className={styles.emptyIcon}>📭</div>
            <h3>暂无会话</h3>
            <p>在电脑上使用 vibe-claude 启动会话</p>
            <code>vibe-claude</code>
          </div>
        )}

        {runningSessions.length > 0 && (
          <section>
            <h2 className={styles.sectionTitle}>运行中的会话</h2>
            {runningSessions.map((session) => (
              <SessionCard
                key={session.session_id}
                session={session}
                onClick={() => setCurrentSessionId(session.session_id)}
              />
            ))}
          </section>
        )}
      </div>
    </div>
  );
}
