// Build script for Node.js server
// Bundles server code into a single CommonJS file for production

import * as esbuild from 'esbuild';
import { fileURLToPath } from 'url';
import path from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function build() {
  console.log('Building server...');

  try {
    await esbuild.build({
      entryPoints: [path.join(__dirname, '../server/index.ts')],
      bundle: true,
      platform: 'node',
      target: 'node18',
      format: 'cjs',
      outfile: path.join(__dirname, '../dist/server.cjs'),
      external: [
        // Native modules that can't be bundled
        'bcrypt',
        // Keep sharp external if used
        'sharp',
      ],
      // Generate source maps for debugging
      sourcemap: true,
      // Minify for production
      minify: process.env.NODE_ENV === 'production',
      // Define environment
      define: {
        'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV || 'production'),
      },
    });

    console.log('Server built successfully: dist/server.cjs');
  } catch (error) {
    console.error('Build failed:', error);
    process.exit(1);
  }
}

build();
