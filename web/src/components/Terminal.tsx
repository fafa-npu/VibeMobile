// Terminal output display component

import { useEffect, useRef } from 'react';
import styles from './Terminal.module.css';

interface TerminalProps {
  output: string;
  autoScroll?: boolean;
}

export function Terminal({ output, autoScroll = true }: TerminalProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const isAtBottomRef = useRef(true);

  // Track if user has scrolled up
  const handleScroll = () => {
    if (!containerRef.current) return;
    const { scrollTop, scrollHeight, clientHeight } = containerRef.current;
    isAtBottomRef.current = scrollHeight - scrollTop - clientHeight < 50;
  };

  // Auto-scroll to bottom when new output arrives
  useEffect(() => {
    if (autoScroll && isAtBottomRef.current && containerRef.current) {
      containerRef.current.scrollTop = containerRef.current.scrollHeight;
    }
  }, [output, autoScroll]);

  // Parse and render output with basic styling
  const renderOutput = () => {
    if (!output) {
      return (
        <div className={styles.placeholder}>
          等待输出...
        </div>
      );
    }

    const lines = output.split('\n');
    const filteredLines: { line: string; index: number }[] = [];

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const trimmedLine = line.trim();

      // Skip lines that are part of Claude Code's TUI box/frame
      // Box drawing characters: ─ │ ╭ ╮ ╰ ╯ ├ ┤ ┬ ┴ ┼ ━ ┃ ┏ ┓ ┗ ┛
      if (/^[│├┤┃]\s/.test(line) || /\s[│├┤┃]$/.test(line)) {
        continue; // Skip box side lines
      }
      if (/^[╭╮╰╯┏┓┗┛┌┐└┘]/.test(trimmedLine) || /[╭╮╰╯┏┓┗┛┌┐└┘]$/.test(trimmedLine)) {
        continue; // Skip box corner lines
      }

      // Skip separator lines (underscores, dashes, box-drawing horizontal lines)
      if (/^[_─━\-=─────]+$/.test(trimmedLine) && trimmedLine.length >= 10) {
        // Add a subtle divider instead
        filteredLines.push({ line: '---divider---', index: i });
        continue;
      }

      // Skip Claude Code welcome box content (lines with │ on both sides)
      if (/^│.*│$/.test(trimmedLine) || /^\|.*\|$/.test(trimmedLine)) {
        continue;
      }

      // Skip empty lines that follow filtered content
      if (trimmedLine === '') {
        // Keep some empty lines for readability, but not too many consecutive ones
        const lastLine = filteredLines[filteredLines.length - 1];
        if (lastLine && (lastLine.line === '' || lastLine.line === '---divider---')) {
          continue;
        }
      }

      filteredLines.push({ line, index: i });
    }

    return filteredLines.map(({ line, index }) => {
      // Render divider
      if (line === '---divider---') {
        return <div key={index} className={styles.divider} />;
      }

      let className = styles.line;

      // Detect line types for styling
      if (line.startsWith('>') || line.startsWith('❯')) {
        className = `${styles.line} ${styles.input}`;
      } else if (line.startsWith('⏺') || line.startsWith('●')) {
        className = `${styles.line} ${styles.response}`;
      } else if (line.includes('✓') || line.includes('成功') || line.includes('pass')) {
        className = `${styles.line} ${styles.success}`;
      } else if (line.includes('✗') || line.includes('失败') || line.includes('error') || line.includes('Error')) {
        className = `${styles.line} ${styles.error}`;
      } else if (line.startsWith('[') && line.includes(']')) {
        className = `${styles.line} ${styles.thinking}`;
      } else if (line.includes('Read') || line.includes('Edit') || line.includes('Bash') || line.includes('Write')) {
        className = `${styles.line} ${styles.tool}`;
      }

      return (
        <div key={index} className={className}>
          {line || '\u00A0'}
        </div>
      );
    });
  };

  return (
    <div
      ref={containerRef}
      className={styles.terminal}
      onScroll={handleScroll}
    >
      {renderOutput()}
    </div>
  );
}
