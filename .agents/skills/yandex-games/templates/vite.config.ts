import { defineConfig } from 'vite';

// CRITICAL FOR YANDEX GAMES:
// base: './' is mandatory because Yandex Games serves games from nested bucket subpaths.
// Absolute URLs (/assets/...) result in 404 errors and fail moderation.
export default defineConfig({
  base: './',
  build: {
    target: 'es2022',
    assetsInlineLimit: 0,
  },
  server: {
    port: 3000,
    open: true,
  },
});
