// tmux session management service
import { spawnSync, execSync } from 'child_process';
import type { Session } from '../types.js';
import { config } from '../config.js';

interface TmuxResult {
  success: boolean;
  output: string;
}

class TmuxManager {
  private prefix = config.tmuxSessionPrefix;
  private captureHistory = config.tmuxCaptureHistory;

  private runTmux(args: string[]): TmuxResult {
    try {
      // Use spawnSync to properly handle arguments without shell interpolation
      const result = spawnSync('tmux', args, {
        timeout: 5000,
        encoding: 'utf-8',
        stdio: ['pipe', 'pipe', 'pipe'],
      });

      if (result.status === 0) {
        return { success: true, output: (result.stdout || '').trim() };
      } else {
        const stderr = result.stderr || result.error?.message || 'Unknown error';
        console.error(`tmux command failed: tmux ${args.join(' ')}, error: ${stderr}`);
        return { success: false, output: stderr };
      }
    } catch (e) {
      const error = e as { message?: string };
      console.error(`tmux command failed: tmux ${args.join(' ')}, error: ${error.message}`);
      return { success: false, output: error.message || 'Unknown error' };
    }
  }

  private isClaudeRunning(sessionId: string): boolean {
    // Get the pane PID
    const { success, output: panePid } = this.runTmux([
      'display-message', '-t', sessionId, '-p', '#{pane_pid}'
    ]);

    if (!success || !panePid) return false;

    try {
      // Check if the process or any child is 'claude'
      const psResult = execSync(`ps -p ${panePid} -o command=`, {
        encoding: 'utf-8',
        timeout: 2000,
      });
      if (psResult.toLowerCase().includes('claude')) return true;

      // Check child processes
      try {
        const pgrepResult = execSync(`pgrep -P ${panePid}`, {
          encoding: 'utf-8',
          timeout: 2000,
        });
        const childPids = pgrepResult.trim().split('\n');
        for (const childPid of childPids) {
          if (childPid) {
            const childPs = execSync(`ps -p ${childPid} -o command=`, {
              encoding: 'utf-8',
              timeout: 2000,
            });
            if (childPs.toLowerCase().includes('claude')) return true;
          }
        }
      } catch {
        // pgrep might fail if no children
      }
    } catch {
      // Process check failed
    }

    return false;
  }

  listSessions(): Session[] {
    const { success, output } = this.runTmux([
      'list-sessions', '-F', '#{session_name}:#{session_created}:#{session_attached}'
    ]);

    if (!success) return [];

    const sessions: Session[] = [];
    const lines = output.split('\n').filter(Boolean);

    for (const line of lines) {
      const parts = line.split(':');
      if (parts.length < 3) continue;

      const [name, createdTs] = parts;

      // Only include sessions with our prefix
      if (!name.startsWith(this.prefix)) continue;

      // Convert timestamp
      let createdAt: Date;
      try {
        createdAt = new Date(parseInt(createdTs, 10) * 1000);
      } catch {
        createdAt = new Date();
      }

      // Determine status based on whether claude is running
      const claudeRunning = this.isClaudeRunning(name);
      const status = claudeRunning ? 'active' : 'ended';

      // Get working directory
      const { output: panePath } = this.runTmux([
        'display-message', '-t', name, '-p', '#{pane_current_path}'
      ]);

      // Get recent output
      const outputTail = this.captureOutput(name) || '';

      sessions.push({
        sessionId: name,
        projectPath: panePath || '',
        status,
        createdAt,
        updatedAt: new Date(),
        outputTail: outputTail.slice(-1000), // Last 1000 chars
      });
    }

    return sessions;
  }

  getSession(sessionId: string): Session | null {
    const sessions = this.listSessions();
    return sessions.find(s => s.sessionId === sessionId) || null;
  }

  sessionExists(sessionId: string): boolean {
    const { success } = this.runTmux(['has-session', '-t', sessionId]);
    return success;
  }

  captureOutput(sessionId: string, withAnsi = false): string | null {
    const args = ['capture-pane', '-t', sessionId, '-p', '-S', `-${this.captureHistory}`];
    if (withAnsi) args.push('-e');

    const { success, output } = this.runTmux(args);
    return success ? output : null;
  }

  sendKeys(sessionId: string, text: string, pressEnter = true): boolean {
    if (!this.sessionExists(sessionId)) return false;

    // Escape special characters for tmux
    const escapedText = text.replace(/"/g, '\\"');
    const { success } = this.runTmux(['send-keys', '-t', sessionId, `"${escapedText}"`]);

    if (!success) return false;

    if (pressEnter) {
      this.runTmux(['send-keys', '-t', sessionId, 'Enter']);
    }

    return true;
  }

  sendSpecialKey(sessionId: string, key: string): boolean {
    if (!this.sessionExists(sessionId)) return false;

    const { success } = this.runTmux(['send-keys', '-t', sessionId, key]);
    return success;
  }

  createSession(command = 'claude', sessionName?: string): string | null {
    if (!sessionName) {
      // Generate a unique session name
      const existing = this.listSessions();
      const existingNames = new Set(existing.map(s => s.sessionId));
      let counter = 1;
      while (existingNames.has(`${this.prefix}-${counter}`)) {
        counter++;
      }
      sessionName = `${this.prefix}-${counter}`;
    }

    const { success } = this.runTmux([
      'new-session', '-d', '-s', sessionName, command
    ]);

    return success ? sessionName : null;
  }

  killSession(sessionId: string): boolean {
    const { success } = this.runTmux(['kill-session', '-t', sessionId]);
    return success;
  }

  getNextSessionName(): string {
    const existing = this.listSessions();
    const existingNums: number[] = [];

    const regex = new RegExp(`^${this.prefix}-(\\d+)$`);
    for (const session of existing) {
      const match = session.sessionId.match(regex);
      if (match) {
        existingNums.push(parseInt(match[1], 10));
      }
    }

    const nextNum = existingNums.length > 0 ? Math.max(...existingNums) + 1 : 1;
    return `${this.prefix}-${nextNum}`;
  }
}

// Singleton instance
export const tmuxManager = new TmuxManager();
