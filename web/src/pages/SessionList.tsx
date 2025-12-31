// Session list page - Scheme B style

import { useSessions, useWebSocket } from '../hooks';
import { useAppStore } from '../stores/appStore';
import { useAuthStore } from '../stores/authStore';
import { SessionCard } from '../components/SessionCard';
import styles from './SessionList.module.css';

export function SessionList() {
  const { data: sessions, isLoading, error } = useSessions();
  const { status } = useWebSocket();
  const setCurrentSessionId = useAppStore((s) => s.setCurrentSessionId);
  const { deviceName, logout } = useAuthStore();

  // All non-ended sessions are "running"
  const runningSessions = sessions?.filter((s) => s.status !== 'ended') || [];
  const endedSessions = sessions?.filter((s) => s.status === 'ended') || [];

  const handleLogout = async () => {
    if (confirm('确定要退出登录吗？')) {
      await logout();
    }
  };

  const getStatusText = () => {
    switch (status) {
      case 'connected': return '已连接';
      case 'connecting': return '连接中...';
      default: return '已断开';
    }
  };

  return (
    <div className={styles.container}>
      <div className={styles.sessionsHeader}>
        <div className={styles.headerRow}>
          <h1>会话</h1>
          <div className={styles.statusChip}>
            <div className={`${styles.statusDot} ${status === 'connecting' ? styles.connecting : status === 'disconnected' ? styles.disconnected : ''}`} />
            <span>{getStatusText()}</span>
          </div>
        </div>
        {deviceName && <p className={styles.deviceName}>{deviceName}</p>}
      </div>

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
            <p className={styles.sectionTitle}>运行中</p>
            {runningSessions.map((session) => (
              <SessionCard
                key={session.session_id}
                session={session}
                onClick={() => setCurrentSessionId(session.session_id)}
              />
            ))}
          </section>
        )}

        {endedSessions.length > 0 && (
          <section>
            <p className={styles.sectionTitle}>已结束</p>
            {endedSessions.map((session) => (
              <SessionCard
                key={session.session_id}
                session={session}
                onClick={() => setCurrentSessionId(session.session_id)}
              />
            ))}
          </section>
        )}
      </div>

      <button className={styles.logoutFab} onClick={handleLogout}>
        退出登录
      </button>
    </div>
  );
}
