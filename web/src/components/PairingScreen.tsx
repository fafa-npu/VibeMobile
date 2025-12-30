// Device pairing screen component - Scheme B style

import { useState } from 'react';
import { useAuthStore } from '../stores/authStore';

export function PairingScreen() {
  const [code, setCode] = useState('');
  const { isPairing, error, startPairing, clearError } = useAuthStore();

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (code.length === 6) {
      startPairing(code);
    }
  };

  const handleCodeChange = (value: string) => {
    const cleaned = value.replace(/\D/g, '').slice(0, 6);
    setCode(cleaned);
    if (error) clearError();
  };

  return (
    <div className="pairing-page">
      <div className="pairing-hero">
        <h1>连接你的<br/>电脑</h1>
        <p>输入 Desktop 应用显示的配对码</p>
      </div>

      <form onSubmit={handleSubmit}>
        <div className="code-card">
          <div className="code-label">配对码</div>
          <input
            type="text"
            className="hidden-input"
            inputMode="numeric"
            pattern="[0-9]*"
            value={code}
            onChange={(e) => handleCodeChange(e.target.value)}
            maxLength={6}
            disabled={isPairing}
            autoFocus
          />
          <div className="code-digits" onClick={() => (document.querySelector('.hidden-input') as HTMLInputElement)?.focus()}>
            {[0, 1, 2, 3, 4, 5].map((i) => (
              <div
                key={i}
                className={`code-digit ${code[i] ? 'filled' : ''} ${i === code.length && code.length < 6 ? 'active' : ''}`}
              >
                {code[i] || ''}
              </div>
            ))}
          </div>
        </div>

        {error && (
          <div className="pairing-error">
            <svg viewBox="0 0 24 24" fill="currentColor" width="18" height="18">
              <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z" />
            </svg>
            {error}
          </div>
        )}

        <button
          type="submit"
          className="pair-btn"
          disabled={code.length !== 6 || isPairing}
        >
          {isPairing ? '连接中...' : '开始连接'}
        </button>
      </form>

      <div className="steps-card">
        <h3>配对步骤</h3>
        <div className="step-item">
          <div className="step-num">1</div>
          <div className="step-text">打开 Desktop 应用</div>
        </div>
        <div className="step-item">
          <div className="step-num">2</div>
          <div className="step-text">点击「配对新设备」</div>
        </div>
        <div className="step-item">
          <div className="step-num">3</div>
          <div className="step-text">输入 6 位配对码</div>
        </div>
        <div className="step-item">
          <div className="step-num">4</div>
          <div className="step-text">确认配对请求</div>
        </div>
      </div>

      <style>{`
        .pairing-page {
          min-height: 100vh;
          background: var(--bg);
          padding: 80px 24px 40px;
        }

        .pairing-hero {
          text-align: center;
          margin-bottom: 48px;
        }

        .pairing-hero h1 {
          font-size: 40px;
          font-weight: 700;
          letter-spacing: -1.5px;
          line-height: 1.1;
          margin-bottom: 12px;
          color: var(--text);
        }

        .pairing-hero p {
          font-size: 18px;
          color: var(--text-secondary);
          line-height: 1.5;
        }

        .code-card {
          background: var(--bg-card);
          border-radius: 24px;
          padding: 32px;
          box-shadow: var(--shadow-lg);
          margin-bottom: 24px;
        }

        .code-label {
          font-size: 14px;
          font-weight: 600;
          color: var(--text-muted);
          text-transform: uppercase;
          letter-spacing: 1px;
          margin-bottom: 16px;
          text-align: center;
        }

        .code-digits {
          display: flex;
          gap: 12px;
          justify-content: center;
          cursor: pointer;
        }

        .code-digit {
          width: 52px;
          height: 72px;
          background: var(--bg-elevated);
          border: 2px solid var(--border);
          border-radius: 16px;
          display: flex;
          align-items: center;
          justify-content: center;
          font-family: 'IBM Plex Mono', monospace;
          font-size: 32px;
          font-weight: 600;
          transition: all 0.2s;
        }

        .code-digit.filled {
          background: var(--accent);
          border-color: var(--accent);
          color: white;
        }

        .code-digit.active {
          border-color: var(--accent-blue);
          box-shadow: 0 0 0 4px rgba(37, 99, 235, 0.2);
        }

        .hidden-input {
          position: absolute;
          opacity: 0;
          pointer-events: none;
        }

        .pairing-error {
          display: flex;
          align-items: center;
          gap: 8px;
          background: rgba(220, 38, 38, 0.1);
          color: var(--accent-red);
          padding: 14px 18px;
          border-radius: 14px;
          font-size: 15px;
          margin-bottom: 20px;
        }

        .pair-btn {
          width: 100%;
          padding: 20px;
          background: var(--accent);
          border: none;
          border-radius: 16px;
          color: white;
          font-family: inherit;
          font-size: 18px;
          font-weight: 600;
          cursor: pointer;
          transition: all 0.2s;
        }

        .pair-btn:disabled {
          background: var(--border);
          color: var(--text-muted);
          cursor: not-allowed;
        }

        .pair-btn:not(:disabled):active {
          transform: scale(0.98);
        }

        .steps-card {
          background: var(--bg-card);
          border-radius: 20px;
          padding: 24px;
          margin-top: 32px;
          box-shadow: var(--shadow);
        }

        .steps-card h3 {
          font-size: 16px;
          font-weight: 700;
          margin-bottom: 20px;
          color: var(--text);
        }

        .step-item {
          display: flex;
          gap: 16px;
          margin-bottom: 16px;
        }

        .step-item:last-child {
          margin-bottom: 0;
        }

        .step-num {
          width: 32px;
          height: 32px;
          background: var(--bg-elevated);
          border-radius: 10px;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 14px;
          font-weight: 700;
          flex-shrink: 0;
          color: var(--text);
        }

        .step-text {
          font-size: 15px;
          color: var(--text-secondary);
          line-height: 1.5;
          padding-top: 4px;
        }
      `}</style>
    </div>
  );
}
