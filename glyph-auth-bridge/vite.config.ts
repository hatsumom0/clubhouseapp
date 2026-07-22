import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// host: true so the iOS Simulator (and devices on the LAN) can reach the dev server
export default defineConfig({
  plugins: [react()],
  server: {
    host: true,
    port: 5173,
  },
  preview: {
    host: true,
    port: 5173,
  },
});
