import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Em desenvolvimento, /api e /up vão para o Rails na porta 3000, como a Vercel faz em
// produção (rewrites do vercel.json).
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      "/api": "http://localhost:3000",
      "/up": "http://localhost:3000",
    },
  },
});
