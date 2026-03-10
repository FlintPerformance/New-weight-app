import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import fs from 'fs';
import path from 'path';

const buildVersion = Date.now().toString(36);

const swVersionPlugin = () => ({
  name: 'sw-version',
  writeBundle({ dir }) {
    try {
      // Stamp service worker with build version
      const swPath = path.join(dir, 'sw.js');
      const content = fs.readFileSync(swPath, 'utf8');
      fs.writeFileSync(swPath, content.replace('__SW_VERSION__', buildVersion));

      // Write version.json for update polling
      fs.writeFileSync(
        path.join(dir, 'version.json'),
        JSON.stringify({ build: buildVersion, timestamp: Date.now() })
      );
    } catch (e) {
      console.error('sw-version plugin error:', e);
    }
  }
});

export default defineConfig({
  define: {
    __APP_BUILD__: JSON.stringify(buildVersion)
  },
  plugins: [react(), swVersionPlugin()],
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          'react-vendor': ['react', 'react-dom'],
          'recharts': ['recharts']
        }
      }
    }
  }
});
