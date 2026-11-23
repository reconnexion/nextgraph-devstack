import { svelte } from '@sveltejs/vite-plugin-svelte'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [svelte()],
  build: {
    sourcemap: false,
    target: 'es2022',
  },
  preview: {
    port: 4174,
  },
})
