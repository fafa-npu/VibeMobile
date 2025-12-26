// Device pairing screen component

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
    // Only allow digits
    const cleaned = value.replace(/\D/g, '').slice(0, 6);
    setCode(cleaned);
    if (error) clearError();
  };

  return (
    <div className="pairing-screen">
      <div className="pairing-container">
        <div className="pairing-header">
          <div className="pairing-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <rect x="5" y="2" width="14" height="20" rx="2" ry="2" />
              <line x1="12" y1="18" x2="12" y2="18" />
            </svg>
          </div>
          <h1>设备配对</h1>
          <p className="pairing-subtitle">
            在 Desktop 应用中生成配对码，然后在下方输入
          </p>
        </div>

        <form onSubmit={handleSubmit} className="pairing-form">
          <div className="code-input-container">
            <input
              type="text"
              inputMode="numeric"
              pattern="[0-9]*"
              value={code}
              onChange={(e) => handleCodeChange(e.target.value)}
              placeholder="000000"
              className="code-input"
              maxLength={6}
              disabled={isPairing}
              autoFocus
            />
            <div className="code-digits">
              {[0, 1, 2, 3, 4, 5].map((i) => (
                <div
                  key={i}
                  className={`code-digit ${code[i] ? 'filled' : ''}`}
                >
                  {code[i] || ''}
                </div>
              ))}
            </div>
          </div>

          {error && (
            <div className="pairing-error">
              <svg viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z" />
              </svg>
              {error}
            </div>
          )}

          <button
            type="submit"
            className="pairing-button"
            disabled={code.length !== 6 || isPairing}
          >
            {isPairing ? (
              <>
                <span className="spinner" />
                等待 Desktop 确认...
              </>
            ) : (
              '连接设备'
            )}
          </button>
        </form>

        <div className="pairing-instructions">
          <h3>配对步骤</h3>
          <ol>
            <li>打开电脑上的 VibeMobile Desktop 应用</li>
            <li>点击 "配对新设备" 按钮</li>
            <li>将显示的 6 位配对码输入上方</li>
            <li>在 Desktop 应用中确认配对请求</li>
          </ol>
        </div>
      </div>

      <style>{`
        .pairing-screen {
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
          padding: 20px;
        }

        .pairing-container {
          max-width: 400px;
          width: 100%;
          background: rgba(255, 255, 255, 0.05);
          border-radius: 20px;
          padding: 40px 30px;
          backdrop-filter: blur(10px);
          border: 1px solid rgba(255, 255, 255, 0.1);
        }

        .pairing-header {
          text-align: center;
          margin-bottom: 30px;
        }

        .pairing-icon {
          width: 60px;
          height: 60px;
          margin: 0 auto 20px;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          border-radius: 16px;
          display: flex;
          align-items: center;
          justify-content: center;
        }

        .pairing-icon svg {
          width: 32px;
          height: 32px;
          color: white;
        }

        .pairing-header h1 {
          color: white;
          font-size: 24px;
          margin: 0 0 10px;
          font-weight: 600;
        }

        .pairing-subtitle {
          color: rgba(255, 255, 255, 0.6);
          font-size: 14px;
          margin: 0;
          line-height: 1.5;
        }

        .pairing-form {
          margin-bottom: 30px;
        }

        .code-input-container {
          position: relative;
          margin-bottom: 20px;
        }

        .code-input {
          position: absolute;
          opacity: 0;
          width: 100%;
          height: 100%;
          cursor: pointer;
        }

        .code-digits {
          display: flex;
          gap: 10px;
          justify-content: center;
        }

        .code-digit {
          width: 45px;
          height: 55px;
          background: rgba(255, 255, 255, 0.1);
          border: 2px solid rgba(255, 255, 255, 0.2);
          border-radius: 12px;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 24px;
          font-weight: 600;
          color: white;
          transition: all 0.2s;
        }

        .code-digit.filled {
          border-color: #667eea;
          background: rgba(102, 126, 234, 0.2);
        }

        .pairing-error {
          display: flex;
          align-items: center;
          gap: 8px;
          background: rgba(220, 38, 38, 0.2);
          color: #fca5a5;
          padding: 12px 16px;
          border-radius: 10px;
          font-size: 14px;
          margin-bottom: 20px;
        }

        .pairing-error svg {
          width: 18px;
          height: 18px;
          flex-shrink: 0;
        }

        .pairing-button {
          width: 100%;
          padding: 16px;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          border: none;
          border-radius: 12px;
          color: white;
          font-size: 16px;
          font-weight: 600;
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 10px;
          transition: all 0.2s;
        }

        .pairing-button:disabled {
          opacity: 0.5;
          cursor: not-allowed;
        }

        .pairing-button:not(:disabled):hover {
          transform: translateY(-2px);
          box-shadow: 0 10px 30px rgba(102, 126, 234, 0.4);
        }

        .spinner {
          width: 20px;
          height: 20px;
          border: 2px solid rgba(255, 255, 255, 0.3);
          border-top-color: white;
          border-radius: 50%;
          animation: spin 1s linear infinite;
        }

        @keyframes spin {
          to { transform: rotate(360deg); }
        }

        .pairing-instructions {
          background: rgba(255, 255, 255, 0.05);
          border-radius: 12px;
          padding: 20px;
        }

        .pairing-instructions h3 {
          color: rgba(255, 255, 255, 0.8);
          font-size: 14px;
          margin: 0 0 15px;
          font-weight: 600;
        }

        .pairing-instructions ol {
          margin: 0;
          padding-left: 20px;
          color: rgba(255, 255, 255, 0.6);
          font-size: 13px;
          line-height: 1.8;
        }
      `}</style>
    </div>
  );
}
