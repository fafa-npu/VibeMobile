// Output monitoring service for tmux sessions
import { tmuxManager } from './tmux.js';
import { wsManager } from './ws.js';
import { config } from '../config.js';
import type { SessionOutput } from '../types.js';

class OutputMonitor {
  private intervals: Map<string, NodeJS.Timeout> = new Map();
  private lastOutputs: Map<string, string> = new Map();
  private running = false;

  startMonitoring(sessionId: string): void {
    if (this.intervals.has(sessionId)) return;

    console.log(`Starting monitor for session: ${sessionId}`);
    this.running = true;

    const interval = setInterval(async () => {
      if (!this.running || !tmuxManager.sessionExists(sessionId)) {
        this.stopMonitoring(sessionId);
        return;
      }

      try {
        const currentOutput = tmuxManager.captureOutput(sessionId);
        if (!currentOutput) return;

        const lastOutput = this.lastOutputs.get(sessionId) || '';

        if (currentOutput !== lastOutput) {
          const output: SessionOutput = {
            sessionId,
            content: currentOutput,
            timestamp: new Date(),
            isDiff: false,
          };
          await wsManager.broadcastOutput(output);

          this.lastOutputs.set(sessionId, currentOutput);
        }
      } catch (e) {
        console.error(`Error monitoring session ${sessionId}:`, e);
      }
    }, config.monitorInterval);

    this.intervals.set(sessionId, interval);
  }

  stopMonitoring(sessionId: string): void {
    const interval = this.intervals.get(sessionId);
    if (interval) {
      clearInterval(interval);
      this.intervals.delete(sessionId);
      this.lastOutputs.delete(sessionId);
      console.log(`Monitor stopped for session: ${sessionId}`);
    }
  }

  async startAll(): Promise<void> {
    this.running = true;
    const sessions = tmuxManager.listSessions();
    for (const session of sessions) {
      this.startMonitoring(session.sessionId);
    }
  }

  stopAll(): void {
    this.running = false;
    for (const sessionId of this.intervals.keys()) {
      this.stopMonitoring(sessionId);
    }
  }

  async refreshSessions(): Promise<void> {
    const sessions = tmuxManager.listSessions();
    const currentSessionIds = new Set(sessions.map(s => s.sessionId));
    const monitoredIds = new Set(this.intervals.keys());

    // Start monitoring new sessions
    for (const sessionId of currentSessionIds) {
      if (!monitoredIds.has(sessionId)) {
        this.startMonitoring(sessionId);
      }
    }

    // Stop monitoring ended sessions
    for (const sessionId of monitoredIds) {
      if (!currentSessionIds.has(sessionId)) {
        this.stopMonitoring(sessionId);
      }
    }
  }

  getFullOutput(sessionId: string): string | null {
    return this.lastOutputs.get(sessionId) || tmuxManager.captureOutput(sessionId);
  }
}

// Singleton instance
export const outputMonitor = new OutputMonitor();
