import { defineConfig } from 'vite';
import path from 'path';
import react from '@vitejs/plugin-react';
import eslint from 'vite-plugin-eslint';

const { PORT = '3000' } = process.env;

const root = path.resolve(__dirname, 'src');

// https://vitejs.dev/config/
export default defineConfig({
  // Relative base: the renderer also loads from file:// inside Electron
  // (absolute /assets paths would resolve to the filesystem root).
  base: './',
  plugins: [react(), eslint()],
  css: {
    preprocessorOptions: {
      less: {
        math: 'always',
      },
    },
  },
  server: {
    host: '127.0.0.1',
    port: parseInt(PORT, 10),
  },
  resolve: {
    alias: {
      '@/': root + '/',
    },
  },
  build: {
    cssMinify: false,
    outDir: 'dist',
  },
});
