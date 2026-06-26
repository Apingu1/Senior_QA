import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    proxy: {
      '/auth': 'http://api:8000',
      '/dashboard': 'http://api:8000',
      '/documents': 'http://api:8000',
      '/tasks': 'http://api:8000',
      '/automation': 'http://api:8000',
      '/questions': 'http://api:8000',
      '/reviews': 'http://api:8000',
      '/outputs': 'http://api:8000',
      '/audit': 'http://api:8000',
      '/health': 'http://api:8000'
    }
  }
})
