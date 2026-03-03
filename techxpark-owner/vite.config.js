import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
  ],
  base: '/',
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: false,
    chunkSizeWarningLimit: 2000,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: [
            'react', 
            'react-dom',
            'react-router-dom'
          ],
          firebase: [
            'firebase/app',
            'firebase/auth',
            'firebase/firestore',
          ],
        }
      }
    }
  },
  resolve: {
    alias: {
      '@': '/src'
    }
  }
})
