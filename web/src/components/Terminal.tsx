// Terminal component - Raw terminal output display
// Shows terminal content as-is with syntax highlighting

import { useEffect, useRef } from 'react';
import styles from './Terminal.module.css';

interface TerminalProps {
  output: string;
  autoScroll?: boolean;
}

// Determine line type for syntax highlighting
function getLineType(line: string): string {
  const trimmed = line.trim();

  // Claude output (starts with ● or ⏺)
  if (/^[●⏺]/.test(trimmed)) return 'claude';

  // User input (starts with > or ❯)
  if (/^[>❯]/.test(trimmed)) return 'user';

  // Tool commands (Bash, Read, Edit, Write, Glob, Grep)
  if (/^\s*(Bash|Read|Edit|Write|Glob|Grep)\s*\(/.test(trimmed)) return 'tool';

  // Tool output (starts with └ or ├)
  if (/^[└├]/.test(trimmed)) return 'output';

  // Status line (starts with *)
  if (/^\*/.test(trimmed)) return 'status';

  // Hint/muted text (keyboard shortcuts, etc.)
  if (/ctrl\+|shift\+|esc\s+to|to run in background|\?\s+for\s+shortcuts/i.test(trimmed)) return 'hint';

  // Separator lines
  if (/^[─━\-=_]+$/.test(trimmed) && trimmed.length >= 5) return 'separator';

  return '';
}

// Check if line should be hidden (terminal input area)
function shouldHideLine(line: string, lines: string[], index: number): boolean {
  const trimmed = line.trim();

  // Hide separator lines that are part of input area
  if (/^[─━\-=_]+$/.test(trimmed) && trimmed.length >= 10) {
    // Check if this is near the end and part of input area
    const remainingLines = lines.length - index;
    if (remainingLines <= 5) return true;
  }

  // Hide empty prompt lines (just > with nothing after)
  if (/^[>❯]\s*$/.test(trimmed)) {
    const remainingLines = lines.length - index;
    if (remainingLines <= 4) return true;
  }

  // Hide status bar lines at the bottom
  if (/^[▶⏵⏸]\s*(bypass|auto-accept|plan mode|normal mode)/i.test(trimmed)) {
    return true;
  }

  // Hide background task info at the bottom
  if (/^\d+\s+background\s+task/i.test(trimmed)) {
    return true;
  }

  return false;
}

export function Terminal({ output, autoScroll = true }: TerminalProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const isAtBottomRef = useRef(true);

  const handleScroll = () => {
    if (!containerRef.current) return;
    const { scrollTop, scrollHeight, clientHeight } = containerRef.current;
    isAtBottomRef.current = scrollHeight - scrollTop - clientHeight < 50;
  };

  useEffect(() => {
    if (autoScroll && isAtBottomRef.current && containerRef.current) {
      containerRef.current.scrollTop = containerRef.current.scrollHeight;
    }
  }, [output, autoScroll]);

  if (!output) {
    return (
      <div ref={containerRef} className={styles.terminal} onScroll={handleScroll}>
        <div className={styles.placeholder}>
          等待输出...
        </div>
      </div>
    );
  }

  const lines = output.split('\n');

  return (
    <div ref={containerRef} className={styles.terminal} onScroll={handleScroll}>
      {lines.map((line, index) => {
        // Skip lines that should be hidden
        if (shouldHideLine(line, lines, index)) {
          return null;
        }

        const lineType = getLineType(line);
        const className = lineType ? `${styles.line} ${styles[lineType]}` : styles.line;

        // Handle empty lines
        if (!line.trim()) {
          return <div key={index} className={`${styles.line} ${styles.empty}`} />;
        }

        return (
          <div key={index} className={className}>
            {line}
          </div>
        );
      })}
    </div>
  );
}
