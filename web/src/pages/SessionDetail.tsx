// Session detail page - Scheme A v2 Chat Bubble style

import { useState } from 'react';
import { useAppStore } from '../stores/appStore';
import { useSession, useSessionOutput, useSendCommand } from '../hooks';
import { api } from '../services/api';
import { Header, type SessionStatus } from '../components/Header';
import { TabBar, type TabType } from '../components/TabBar';
import { Terminal } from '../components/Terminal';
import { CommandInput } from '../components/CommandInput';
import FileBrowser from '../components/FileBrowser';
import styles from './SessionDetail.module.css';

export function SessionDetail() {
  const currentSessionId = useAppStore((s) => s.currentSessionId);
  const setCurrentSessionId = useAppStore((s) => s.setCurrentSessionId);
  const sessionOutputs = useAppStore((s) => s.sessionOutputs);
  const [activeTab, setActiveTab] = useState<TabType>('terminal');

  const { data: session } = useSession(currentSessionId);
  const { isLoading } = useSessionOutput(currentSessionId);
  const sendCommand = useSendCommand();

  const output = currentSessionId ? sessionOutputs[currentSessionId] || '' : '';

  // Map session status to UI status
  const getHeaderStatus = (): SessionStatus => {
    if (!session) return 'waiting';
    if (session.status === 'ended') return 'ended';
    if (session.status === 'active') return 'running';
    return 'waiting';
  };

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

  // Extract session name from session_id (e.g., "vibe-1" from "vibe-1")
  const sessionName = session?.session_id?.replace(/^vibe-/, '') || currentSessionId;

  return (
    <div className={styles.container}>
      {/* Header */}
      <Header
        title={`vibe-${sessionName}`}
        subtitle={session?.project_path || ''}
        showBack
        onBack={handleBack}
        status={getHeaderStatus()}
      />

      {/* Tab Bar */}
      <TabBar activeTab={activeTab} onTabChange={setActiveTab} />

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
            placeholder={sendCommand.isPending ? '发送中...' : 'Message...'}
            backgroundTasks={3}
            tokenCount="2.1k"
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
