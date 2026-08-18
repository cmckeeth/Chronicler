import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { readFileSync } from 'fs';

const pkg = JSON.parse(readFileSync(new URL('./package.json', import.meta.url)));
// Single source of truth for the shipped version: deploy.sh computes it from the
// repo-root VERSION file + git commit count and passes it through as a Docker
// build arg (this build context has neither file). package.json is the fallback
// for local `npm run dev` / `npm run build`.
const appVersion = process.env.APP_VERSION?.trim() || pkg.version;
// Build-machine clock — inside Docker this is the deploy time, so it changes every deploy.
const buildTime = new Date().toISOString().slice(0, 16).replace('T', ' ');

export default defineConfig({
  plugins: [react()],
  define: {
    __APP_VERSION__: JSON.stringify(appVersion),
    __BUILD_TIME__: JSON.stringify(buildTime),
  },
  server: {
    proxy: {
      '/api': 'http://localhost:5160'
    }
  }
});
