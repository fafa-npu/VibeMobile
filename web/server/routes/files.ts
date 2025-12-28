// File browser API routes
import { Router } from 'express';
import fs from 'fs/promises';
import fsSync from 'fs';
import path from 'path';
import { tmuxManager } from '../services/tmux.js';
import { authContextMiddleware, requireAuth } from '../middleware/auth.js';

const router = Router();

// Maximum file size for preview (1MB)
const MAX_PREVIEW_SIZE = 1024 * 1024;

// Maximum media file size for preview (10MB)
const MAX_MEDIA_SIZE = 10 * 1024 * 1024;

// Binary file extensions that should not be previewed as text
const BINARY_EXTENSIONS = new Set([
  '.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.bmp', '.svg',
  '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
  '.zip', '.tar', '.gz', '.rar', '.7z',
  '.exe', '.dll', '.so', '.dylib',
  '.woff', '.woff2', '.ttf', '.otf', '.eot',
  '.pyc', '.pyo', '.class', '.o', '.obj',
]);

// Media file extensions that can be previewed with base64 encoding
const MEDIA_EXTENSIONS = new Set([
  // Audio
  '.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a',
  // Video
  '.mp4', '.webm', '.mov', '.avi', '.mkv',
]);

// Sensitive files/directories that should be filtered
const SENSITIVE_PATTERNS = [
  /^\.env/,
  /^\.git$/,
  /node_modules/,
  /^credentials/i,
  /^secrets/i,
  /\.pem$/,
  /\.key$/,
  /^\.ssh$/,
];

// Security check: prevent path traversal attacks
function isPathSafe(basePath: string, requestedPath: string): boolean {
  const resolvedBase = path.resolve(basePath);
  const resolvedPath = path.resolve(basePath, requestedPath);
  return resolvedPath.startsWith(resolvedBase);
}

// Check if a file/directory is sensitive
function isSensitive(name: string): boolean {
  return SENSITIVE_PATTERNS.some(pattern => pattern.test(name));
}

// Check if a file is binary based on extension
function isBinaryFile(filename: string): boolean {
  const ext = path.extname(filename).toLowerCase();
  return BINARY_EXTENSIONS.has(ext);
}

// Check if a file is a media file (audio/video)
function isMediaFile(filename: string): boolean {
  const ext = path.extname(filename).toLowerCase();
  return MEDIA_EXTENSIONS.has(ext);
}

// Get project path for a session
function getSessionProjectPath(sessionId: string): string | null {
  const session = tmuxManager.getSession(sessionId);
  return session?.projectPath || null;
}

// Apply auth context middleware
router.use(authContextMiddleware);

// GET /api/sessions/:sessionId/files - List directory or get file content
router.get('/:sessionId/files', requireAuth, async (req, res) => {
  const { sessionId } = req.params;
  const relativePath = (req.query.path as string) || '.';

  try {
    // Get session's project path
    const projectPath = getSessionProjectPath(sessionId);
    if (!projectPath) {
      res.status(404).json({ error: 'Session not found or has no project path' });
      return;
    }

    // Security check
    if (!isPathSafe(projectPath, relativePath)) {
      res.status(403).json({ error: 'Access denied: path traversal attempt' });
      return;
    }

    const fullPath = path.join(projectPath, relativePath);

    // Check if path exists
    try {
      await fs.access(fullPath);
    } catch {
      res.status(404).json({ error: 'Path not found' });
      return;
    }

    const stat = await fs.stat(fullPath);

    if (stat.isDirectory()) {
      // List directory contents
      const entries = await fs.readdir(fullPath, { withFileTypes: true });

      // Filter sensitive files and sort (directories first, then alphabetically)
      const items = entries
        .filter(entry => !isSensitive(entry.name))
        .map(entry => ({
          name: entry.name,
          isDirectory: entry.isDirectory(),
          path: path.join(relativePath, entry.name).replace(/\\/g, '/'),
        }))
        .sort((a, b) => {
          if (a.isDirectory && !b.isDirectory) return -1;
          if (!a.isDirectory && b.isDirectory) return 1;
          return a.name.localeCompare(b.name);
        });

      res.json({
        type: 'directory',
        path: relativePath,
        items,
      });
    } else {
      // Return file content
      const filename = path.basename(fullPath);

      // Check if media file (audio/video) - return as base64
      if (isMediaFile(filename)) {
        // Check media file size limit
        if (stat.size > MAX_MEDIA_SIZE) {
          res.json({
            type: 'file',
            path: relativePath,
            name: filename,
            size: stat.size,
            isBinary: true,
            isMedia: true,
            content: null,
            message: `Media file too large to preview (${(stat.size / 1024 / 1024).toFixed(2)}MB > 10MB limit)`,
          });
          return;
        }

        // Read file as base64
        const content = await fs.readFile(fullPath);
        res.json({
          type: 'file',
          path: relativePath,
          name: filename,
          size: stat.size,
          isBinary: true,
          isMedia: true,
          content: content.toString('base64'),
        });
        return;
      }

      // Check if binary
      if (isBinaryFile(filename)) {
        res.json({
          type: 'file',
          path: relativePath,
          name: filename,
          size: stat.size,
          isBinary: true,
          content: null,
          message: 'Binary file cannot be previewed',
        });
        return;
      }

      // Check file size
      if (stat.size > MAX_PREVIEW_SIZE) {
        res.json({
          type: 'file',
          path: relativePath,
          name: filename,
          size: stat.size,
          isBinary: false,
          content: null,
          message: `File too large to preview (${(stat.size / 1024 / 1024).toFixed(2)}MB > 1MB limit)`,
        });
        return;
      }

      // Read and return file content
      const content = await fs.readFile(fullPath, 'utf-8');
      res.json({
        type: 'file',
        path: relativePath,
        name: filename,
        size: stat.size,
        isBinary: false,
        content,
      });
    }
  } catch (e) {
    console.error(`Error accessing files for session ${sessionId}:`, e);
    res.status(500).json({ error: 'Failed to access files' });
  }
});

// GET /api/sessions/:sessionId/files/tree - Get directory tree
router.get('/:sessionId/files/tree', requireAuth, async (req, res) => {
  const { sessionId } = req.params;
  const maxDepth = parseInt(req.query.depth as string) || 3;

  try {
    const projectPath = getSessionProjectPath(sessionId);
    if (!projectPath) {
      res.status(404).json({ error: 'Session not found or has no project path' });
      return;
    }

    interface TreeNode {
      name: string;
      path: string;
      isDirectory: boolean;
      children?: TreeNode[];
    }

    async function buildTree(dir: string, relativePath: string, depth: number): Promise<TreeNode[]> {
      if (depth <= 0) return [];

      try {
        const entries = await fs.readdir(dir, { withFileTypes: true });
        const nodes: TreeNode[] = [];

        for (const entry of entries) {
          if (isSensitive(entry.name)) continue;

          const entryRelativePath = path.join(relativePath, entry.name).replace(/\\/g, '/');
          const node: TreeNode = {
            name: entry.name,
            path: entryRelativePath,
            isDirectory: entry.isDirectory(),
          };

          if (entry.isDirectory()) {
            node.children = await buildTree(
              path.join(dir, entry.name),
              entryRelativePath,
              depth - 1
            );
          }

          nodes.push(node);
        }

        // Sort: directories first, then alphabetically
        return nodes.sort((a, b) => {
          if (a.isDirectory && !b.isDirectory) return -1;
          if (!a.isDirectory && b.isDirectory) return 1;
          return a.name.localeCompare(b.name);
        });
      } catch {
        return [];
      }
    }

    const tree = await buildTree(projectPath, '.', maxDepth);
    res.json({
      type: 'tree',
      root: projectPath,
      children: tree,
    });
  } catch (e) {
    console.error(`Error building file tree for session ${sessionId}:`, e);
    res.status(500).json({ error: 'Failed to build file tree' });
  }
});

export default router;
