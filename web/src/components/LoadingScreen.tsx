// Loading screen component - Scheme B style

export function LoadingScreen() {
  return (
    <div className="loading-screen">
      <div className="loading-brand">
        <div className="loading-logo">📱</div>
        <h1>VibeMobile</h1>
        <p>远程控制 Claude Code</p>
      </div>
      <div className="loading-spinner"></div>

      <style>{`
        .loading-screen {
          min-height: 100vh;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          gap: 40px;
          background: var(--accent);
        }

        .loading-brand {
          text-align: center;
        }

        .loading-logo {
          width: 120px;
          height: 120px;
          background: var(--bg);
          border-radius: 32px;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 56px;
          margin: 0 auto 24px;
          box-shadow: 0 20px 60px rgba(0,0,0,0.5);
        }

        .loading-brand h1 {
          font-size: 36px;
          font-weight: 700;
          color: var(--bg);
          letter-spacing: -1px;
          margin: 0;
        }

        .loading-brand p {
          color: var(--text-muted);
          font-size: 16px;
          margin-top: 8px;
        }

        .loading-spinner {
          width: 40px;
          height: 40px;
          border: 3px solid rgba(255,255,255,0.2);
          border-top-color: white;
          border-radius: 50%;
          animation: spin 1s linear infinite;
        }

        @keyframes spin {
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
}
