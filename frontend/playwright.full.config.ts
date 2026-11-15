import { defineConfig, devices } from "@playwright/test";

// Duelo de ponta a ponta (GXP-57): o build de produção e o Rails de verdade, no banco de
// teste preparado pelo "bin/rails e2e:preparar". Sem a chave do Ably, as telas consultam a
// API a cada 2 s, como quando o tempo real cai.
export default defineConfig({
  testDir: "e2e-full",
  timeout: 60_000,
  forbidOnly: !!process.env.CI,
  reporter: process.env.CI ? [["github"], ["html", { open: "never" }]] : "list",
  use: { baseURL: "http://localhost:4174", locale: "pt-BR" },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: [
    {
      command: "bin/rails server -e test -p 3000",
      cwd: "../backend",
      url: "http://localhost:3000/up",
      timeout: 60_000,
      reuseExistingServer: !process.env.CI,
    },
    {
      command: "npm run build && npm run preview -- --port 4174 --strictPort",
      url: "http://localhost:4174",
      reuseExistingServer: !process.env.CI,
    },
  ],
});
