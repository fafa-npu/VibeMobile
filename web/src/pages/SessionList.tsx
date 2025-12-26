// Session list page

import { useSessions, useWebSocket } from '../hooks';
import { useAppStore } from '../stores/appStore';
import { useAuthStore } from '../stores/authStore';
import { Header } from '../components/Header';
import { SessionCard } from '../components/SessionCard';
import styles from './SessionList.module.css';

export function SessionList() {
  const { data: sessions, isLoading, error } = useSessions();
  const { status } = useWebSocket();
  const setCurrentSessionId = useAppStore((s) => s.setCurrentSessionId);
  const { deviceName, logout } = useAuthStore();

  // All non-ended sessions are "running"
  const runningSessions = sessions?.filter((s) => s.status !== 'ended') || [];

  const handleLogout = async () => {
    if (confirm('确定要退出登录吗？')) {
      await logout();
    }
  };

  return (
    <div className={styles.container}>
      <Header
        title="VibeMobile"
        subtitle={deviceName || undefined}
        status={status}
        rightElement={
          <button
            className={styles.logoutBtn}
            onClick={handleLogout}
            title="退出登录"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
              <polyline points="16 17 21 12 16 7" />
              <line x1="21" y1="12" x2="9" y2="12" />
            </svg>
          </button>
        }
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
