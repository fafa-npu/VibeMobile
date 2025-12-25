// Session detail page

import { useAppStore } from '../stores/appStore';
import { useSession, useSessionOutput, useSendCommand } from '../hooks';
import { api } from '../services/api';
import { Header } from '../components/Header';
import { Terminal } from '../components/Terminal';
import { CommandInput } from '../components/CommandInput';
import styles from './SessionDetail.module.css';

export function SessionDetail() {
  const currentSessionId = useAppStore((s) => s.currentSessionId);
  const setCurrentSessionId = useAppStore((s) => s.setCurrentSessionId);
  const sessionOutputs = useAppStore((s) => s.sessionOutputs);

  const { data: session } = useSession(currentSessionId);
  const { isLoading } = useSessionOutput(currentSessionId);
  const sendCommand = useSendCommand();

  const output = currentSessionId ? sessionOutputs[currentSessionId] || '' : '';

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
      <Header
        title={session?.session_id || currentSessionId}
        subtitle={session?.project_path || ''}
        showBack
        onBack={handleBack}
        rightElement={
          <span
            className={`${styles.status} ${
              session?.status === 'ended' ? styles.ended : styles.active
            }`}
          >
            {session?.status === 'ended' ? '已结束' : '运行中'}
          </span>
        }
      />

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
    </div>
  );
}
