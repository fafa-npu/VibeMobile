import { useState, useEffect, useCallback, useMemo } from 'react';
import { marked } from 'marked';
import { api } from '../../services/api';
import type { FileItem, FileResponse } from '../../types';
import styles from './FileBrowser.module.css';

// Configure marked for safe rendering
marked.setOptions({
  gfm: true,
  breaks: true,
});

interface FileBrowserProps {
  sessionId: string;
  projectPath?: string;
}

// File type configurations
const FILE_ICONS: Record<string, string> = {
  folder: '📁',
  html: '🌐',
  css: '🎨',
  js: '📒',
  jsx: '📒',
  ts: '📘',
  tsx: '📘',
  json: '📋',
  md: '📝',
  py: '🐍',
  rs: '🦀',
  go: '🐹',
  png: '🖼️',
  jpg: '🖼️',
  jpeg: '🖼️',
  gif: '🖼️',
  svg: '🖼️',
  // Audio files
  mp3: '🎵',
  wav: '🎵',
  flac: '🎵',
  aac: '🎵',
  ogg: '🎵',
  m4a: '🎵',
  // Video files
  mp4: '🎬',
  webm: '🎬',
  mov: '🎬',
  avi: '🎬',
  mkv: '🎬',
  default: '📄',
};

function getFileIcon(filename: string, isDirectory: boolean): string {
  if (isDirectory) return FILE_ICONS.folder;
  const ext = filename.split('.').pop()?.toLowerCase() || '';
  return FILE_ICONS[ext] || FILE_ICONS.default;
}

function getFileIconClass(filename: string, isDirectory: boolean): string {
  if (isDirectory) return 'folder';
  const ext = filename.split('.').pop()?.toLowerCase() || '';
  const imageExts = ['png', 'jpg', 'jpeg', 'gif', 'svg', 'webp'];
  const audioExts = ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'];
  const videoExts = ['mp4', 'webm', 'mov', 'avi', 'mkv'];
  if (imageExts.includes(ext)) return 'image';
  if (audioExts.includes(ext)) return 'audio';
  if (videoExts.includes(ext)) return 'video';
  if (['ts', 'tsx'].includes(ext)) return 'ts';
  if (['js', 'jsx'].includes(ext)) return 'js';
  if (['html', 'htm'].includes(ext)) return 'html';
  if (['css', 'scss', 'less'].includes(ext)) return 'css';
  if (ext === 'json') return 'json';
  if (ext === 'md') return 'md';
  return 'file';
}

function getFileLanguage(filename: string): string {
  const ext = filename.split('.').pop()?.toLowerCase() || '';
  const langMap: Record<string, string> = {
    ts: 'TypeScript', tsx: 'TypeScript', js: 'JavaScript', jsx: 'JavaScript',
    html: 'HTML', htm: 'HTML', css: 'CSS', scss: 'SCSS', json: 'JSON',
    md: 'Markdown', py: 'Python', rs: 'Rust', go: 'Go',
    // Audio
    mp3: 'Audio', wav: 'Audio', flac: 'Audio', aac: 'Audio', ogg: 'Audio', m4a: 'Audio',
    // Video
    mp4: 'Video', webm: 'Video', mov: 'Video', avi: 'Video', mkv: 'Video',
  };
  return langMap[ext] || 'Text';
}

function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(2)} MB`;
}

function isHtmlFile(filename: string): boolean {
  const ext = filename.split('.').pop()?.toLowerCase() || '';
  return ['html', 'htm'].includes(ext);
}

function isMarkdownFile(filename: string): boolean {
  const ext = filename.split('.').pop()?.toLowerCase() || '';
  return ['md', 'markdown'].includes(ext);
}

function isImageFile(filename: string): boolean {
  const ext = filename.split('.').pop()?.toLowerCase() || '';
  return ['png', 'jpg', 'jpeg', 'gif', 'svg', 'webp'].includes(ext);
}

function isAudioFile(filename: string): boolean {
  const ext = filename.split('.').pop()?.toLowerCase() || '';
  return ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'].includes(ext);
}

function isVideoFile(filename: string): boolean {
  const ext = filename.split('.').pop()?.toLowerCase() || '';
  return ['mp4', 'webm', 'mov', 'avi', 'mkv'].includes(ext);
}

function getAudioMimeType(filename: string): string {
  const ext = filename.split('.').pop()?.toLowerCase() || '';
  const mimeMap: Record<string, string> = {
    mp3: 'audio/mpeg',
    wav: 'audio/wav',
    flac: 'audio/flac',
    aac: 'audio/aac',
    ogg: 'audio/ogg',
    m4a: 'audio/mp4',
  };
  return mimeMap[ext] || 'audio/mpeg';
}

function getVideoMimeType(filename: string): string {
  const ext = filename.split('.').pop()?.toLowerCase() || '';
  const mimeMap: Record<string, string> = {
    mp4: 'video/mp4',
    webm: 'video/webm',
    mov: 'video/quicktime',
    avi: 'video/x-msvideo',
    mkv: 'video/x-matroska',
  };
  return mimeMap[ext] || 'video/mp4';
}

export default function FileBrowser({ sessionId }: FileBrowserProps) {
  const [currentPath, setCurrentPath] = useState<string>('.');
  const [items, setItems] = useState<FileItem[]>([]);
  const [selectedFile, setSelectedFile] = useState<FileResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');

  // Build breadcrumb path parts
  const pathParts = useMemo(() => {
    if (currentPath === '.') return [{ name: '根目录', path: '.' }];
    const parts = currentPath.split('/').filter(Boolean);
    return [
      { name: '根目录', path: '.' },
      ...parts.map((part, index) => ({
        name: part,
        path: parts.slice(0, index + 1).join('/'),
      })),
    ];
  }, [currentPath]);

  // Load directory contents
  const loadDirectory = useCallback(async (path: string) => {
    setLoading(true);
    setError(null);
    setSelectedFile(null);
    try {
      const response = await api.getFiles(sessionId, path);
      if (response.type === 'directory') {
        // Sort: folders first, then files alphabetically
        const sorted = [...response.items].sort((a, b) => {
          if (a.isDirectory !== b.isDirectory) {
            return a.isDirectory ? -1 : 1;
          }
          return a.name.localeCompare(b.name);
        });
        setItems(sorted);
        setCurrentPath(path);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load directory');
    } finally {
      setLoading(false);
    }
  }, [sessionId]);

  // Load initial directory
  useEffect(() => {
    loadDirectory('.');
  }, [loadDirectory]);

  // Handle item click
  const handleItemClick = useCallback(async (item: FileItem) => {
    if (item.isDirectory) {
      loadDirectory(item.path);
    } else {
      // Load file content
      try {
        setLoading(true);
        const response = await api.getFiles(sessionId, item.path);
        if (response.type === 'file') {
          setSelectedFile(response);
        }
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load file');
      } finally {
        setLoading(false);
      }
    }
  }, [sessionId, loadDirectory]);

  // Handle breadcrumb navigation
  const handleBreadcrumbClick = useCallback((path: string) => {
    loadDirectory(path);
  }, [loadDirectory]);

  // Handle back from preview
  const handleBackFromPreview = useCallback(() => {
    setSelectedFile(null);
  }, []);

  // Filter items by search query
  const filteredItems = useMemo(() => {
    if (!searchQuery.trim()) return items;
    const query = searchQuery.toLowerCase();
    return items.filter(item => item.name.toLowerCase().includes(query));
  }, [items, searchQuery]);

  // Render file preview
  const renderPreview = () => {
    if (!selectedFile) return null;

    const filename = selectedFile.path.split('/').pop() || '';

    return (
      <div className={styles.previewPanel}>
        <div className={styles.previewHeader}>
          <button className={styles.toolbarBtn} onClick={handleBackFromPreview}>
            ←
          </button>
          <div className={styles.previewTitle}>
            <div className={styles.previewFileName}>{filename}</div>
            <div className={styles.previewMeta}>
              {getFileLanguage(filename)} • {formatFileSize(selectedFile.size || 0)}
            </div>
          </div>
        </div>
        <div className={styles.previewContent}>
          {isHtmlFile(filename) ? (
            <iframe
              className={styles.htmlPreview}
              srcDoc={selectedFile.content || ''}
              title="HTML Preview"
              sandbox="allow-scripts"
            />
          ) : isMarkdownFile(filename) ? (
            <div
              className={styles.markdownPreview}
              dangerouslySetInnerHTML={{
                __html: marked.parse(selectedFile.content || '') as string
              }}
            />
          ) : isImageFile(filename) ? (
            <div className={styles.imagePreview}>
              <img
                src={`data:image/${filename.split('.').pop()};base64,${selectedFile.content}`}
                alt={filename}
              />
            </div>
          ) : isAudioFile(filename) ? (
            <div className={styles.audioPreview}>
              <div className={styles.audioIcon}>🎵</div>
              <div className={styles.audioFileName}>{filename}</div>
              <audio
                className={styles.audioPlayer}
                controls
                src={`data:${getAudioMimeType(filename)};base64,${selectedFile.content}`}
              >
                Your browser does not support the audio element.
              </audio>
            </div>
          ) : isVideoFile(filename) ? (
            <div className={styles.videoPreview}>
              <video
                className={styles.videoPlayer}
                controls
                src={`data:${getVideoMimeType(filename)};base64,${selectedFile.content}`}
              >
                Your browser does not support the video element.
              </video>
            </div>
          ) : !selectedFile.content ? (
            <div className={styles.binaryMessage}>
              <span className={styles.binaryIcon}>📦</span>
              <span>{(selectedFile as { message?: string }).message || 'Binary file cannot be previewed'}</span>
            </div>
          ) : (
            <pre className={styles.codePreview}>{selectedFile.content}</pre>
          )}
        </div>
      </div>
    );
  };

  // Render file list
  const renderFileList = () => (
    <>
      {/* Toolbar */}
      <div className={styles.toolbar}>
        <div className={styles.breadcrumb}>
          {pathParts.map((part, index) => (
            <span key={part.path}>
              {index > 0 && <span className={styles.breadcrumbSep}>/</span>}
              <span
                className={styles.breadcrumbItem}
                onClick={() => index < pathParts.length - 1 && handleBreadcrumbClick(part.path)}
              >
                {part.name}
              </span>
            </span>
          ))}
        </div>
        <button className={styles.toolbarBtn} onClick={() => loadDirectory(currentPath)}>
          ↻
        </button>
      </div>

      {/* Search Bar */}
      <div className={styles.searchBar}>
        <div className={styles.searchWrapper}>
          <span className={styles.searchIcon}>🔍</span>
          <input
            type="text"
            className={styles.searchInput}
            placeholder="Search files..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
      </div>

      {/* File List */}
      <div className={styles.fileList}>
        {loading ? (
          <div className={styles.loadingState}>
            <div className={styles.spinner} />
            <span>Loading...</span>
          </div>
        ) : error ? (
          <div className={styles.errorState}>
            <span className={styles.errorIcon}>⚠️</span>
            <span className={styles.errorText}>{error}</span>
            <button className={styles.retryBtn} onClick={() => loadDirectory(currentPath)}>
              Retry
            </button>
          </div>
        ) : filteredItems.length === 0 ? (
          <div className={styles.emptyState}>
            <span className={styles.emptyIcon}>📂</span>
            <span className={styles.emptyText}>
              {searchQuery ? 'No matching files' : 'Empty folder'}
            </span>
          </div>
        ) : (
          filteredItems.map((item) => (
            <div
              key={item.path}
              className={styles.fileItem}
              onClick={() => handleItemClick(item)}
            >
              <div className={`${styles.fileIcon} ${styles[getFileIconClass(item.name, item.isDirectory)]}`}>
                {getFileIcon(item.name, item.isDirectory)}
              </div>
              <div className={styles.fileInfo}>
                <div className={styles.fileName}>{item.name}</div>
                <div className={styles.fileMeta}>
                  {item.isDirectory ? 'Folder' : getFileLanguage(item.name)}
                </div>
              </div>
              <span className={styles.fileArrow}>›</span>
            </div>
          ))
        )}
      </div>
    </>
  );

  return (
    <div className={styles.container}>
      {selectedFile ? renderPreview() : renderFileList()}
    </div>
  );
}
