import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import fs from 'fs'
import path from 'path'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    host: true, // Allow external access
    https: {
      key: fs.readFileSync(path.resolve(__dirname, '../certs/localhost-key.pem')),
      cert: fs.readFileSync(path.resolve(__dirname, '../certs/localhost.pem')),
    },
    // Disable HMR when accessed via tunnel (or configure for tunnel hostname)
    hmr: false,
    proxy: {
      '/api': {
        target: 'https://localhost:8765',
        changeOrigin: true,
        secure: false, // Accept self-signed certificates
      },
      '/ws': {
        target: 'wss://localhost:8765',
        ws: true,
        secure: false, // Accept self-signed certificates
      },
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
  },
})
