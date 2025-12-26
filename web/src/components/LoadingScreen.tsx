// Loading screen component

export function LoadingScreen() {
  return (
    <div className="loading-screen">
      <div className="loading-container">
        <div className="loading-spinner">
          <svg viewBox="0 0 50 50">
            <circle cx="25" cy="25" r="20" fill="none" strokeWidth="4" />
          </svg>
        </div>
        <p>正在初始化...</p>
      </div>

      <style>{`
        .loading-screen {
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
        }

        .loading-container {
          text-align: center;
        }

        .loading-spinner {
          width: 60px;
          height: 60px;
          margin: 0 auto 20px;
        }

        .loading-spinner svg {
          animation: rotate 2s linear infinite;
        }

        .loading-spinner circle {
          stroke: #667eea;
          stroke-linecap: round;
          animation: dash 1.5s ease-in-out infinite;
        }

        @keyframes rotate {
          100% { transform: rotate(360deg); }
        }

        @keyframes dash {
          0% {
            stroke-dasharray: 1, 150;
            stroke-dashoffset: 0;
          }
          50% {
            stroke-dasharray: 90, 150;
            stroke-dashoffset: -35;
          }
          100% {
            stroke-dasharray: 90, 150;
            stroke-dashoffset: -124;
          }
        }

        .loading-container p {
          color: rgba(255, 255, 255, 0.6);
          font-size: 14px;
          margin: 0;
        }
      `}</style>
    </div>
  );
}
