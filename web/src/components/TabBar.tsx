// TabBar component for switching between Terminal and Files views

import styles from './TabBar.module.css';

export type TabType = 'terminal' | 'files';

interface TabBarProps {
  activeTab: TabType;
  onTabChange: (tab: TabType) => void;
}

export function TabBar({ activeTab, onTabChange }: TabBarProps) {
  return (
    <div className={styles.tabBar} role="tablist">
      <button
        role="tab"
        aria-selected={activeTab === 'terminal'}
        className={`${styles.tabBtn} ${activeTab === 'terminal' ? styles.active : ''}`}
        onClick={() => onTabChange('terminal')}
      >
        💬 终端
      </button>
      <button
        role="tab"
        aria-selected={activeTab === 'files'}
        className={`${styles.tabBtn} ${activeTab === 'files' ? styles.active : ''}`}
        onClick={() => onTabChange('files')}
      >
        📁 文件
      </button>
    </div>
  );
}
