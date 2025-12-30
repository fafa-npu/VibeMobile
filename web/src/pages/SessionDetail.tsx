// Session detail page - Scheme B style

import { useState } from 'react';
import { useAppStore } from '../stores/appStore';
import { useSession, useSessionOutput, useSendCommand } from '../hooks';
import { api } from '../services/api';
import { Terminal } from '../components/Terminal';
import { CommandInput } from '../components/CommandInput';
import FileBrowser from '../components/FileBrowser';
import styles from './SessionDetail.module.css';

type TabType = 'terminal' | 'files';

export function SessionDetail() {
  const currentSessionId = useAppStore((s) => s.currentSessionId);
  const setCurrentSessionId = useAppStore((s) => s.setCurrentSessionId);
  const sessionOutputs = useAppStore((s) => s.sessionOutputs);
  const [activeTab, setActiveTab] = useState<TabType>('terminal');

  const { data: session } = useSession(currentSessionId);
  const { isLoading } = useSessionOutput(currentSessionId);
  const sendCommand = useSendCommand();

  const output = currentSessionId ? sessionOutputs[currentSessionId] || '' : '';
  const isEnded = session?.status === 'ended';

  const handleBack = () => {
    setCurrentSessionId(null);
  };

  const handleSend = (content: string) => {
    if (!currentSessionId) return;
    sendCommand.mutate({ sessionId: currentSessionId, content });
  };

  const handleSpecialKey = async (key: string) => {
    if (!currentSessionId) return;
    try {
      await api.sendSpecialKey(currentSessionId, key);
    } catch (e) {
      console.error('Failed to send special key:', e);
    }
  };

  const handleUpload = async (file: File) => {
    if (!currentSessionId) return;
    try {
      await api.uploadFile(currentSessionId, file);
    } catch (e) {
      console.error('Failed to upload file:', e);
    }
  };

  if (!currentSessionId) {
    return null;
  }

  return (
    <div className={styles.container}>
      {/* Header */}
      <div className={styles.detailHeader}>
        <div className={styles.detailTop}>
          <button className={styles.backBtn} onClick={handleBack}>←</button>
          <div className={styles.detailInfo}>
            <h1>{session?.session_id || currentSessionId}</h1>
            <p>{session?.project_path || ''}</p>
          </div>
          <span className={`${styles.detailBadge} ${isEnded ? styles.ended : styles.active}`}>
            {isEnded ? '已结束' : '运行中'}
          </span>
        </div>
        <div className={styles.tabBar}>
          <button
            className={`${styles.tabBtn} ${activeTab === 'terminal' ? styles.active : ''}`}
            onClick={() => setActiveTab('terminal')}
          >
            💬 终端
          </button>
          <button
            className={`${styles.tabBtn} ${activeTab === 'files' ? styles.active : ''}`}
            onClick={() => setActiveTab('files')}
          >
            📁 文件
          </button>
        </div>
      </div>

      {activeTab === 'terminal' ? (
        <>
          <div className={styles.terminalWrapper}>
            {isLoading ? (
              <div className={styles.loading}>
                <div className={styles.spinner} />
              </div>
            ) : (
              <Terminal output={output} />
            )}
          </div>

          <CommandInput
            onSend={handleSend}
            onSpecialKey={handleSpecialKey}
            onUpload={handleUpload}
            disabled={sendCommand.isPending}
            placeholder={sendCommand.isPending ? '发送中...' : '输入指令...'}
          />
        </>
      ) : (
        <div className={styles.filesWrapper}>
          <FileBrowser
            sessionId={currentSessionId}
            projectPath={session?.project_path}
          />
        </div>
      )}
    </div>
  );
}
