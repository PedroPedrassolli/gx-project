import type { Page } from "@playwright/test";

export const PLAYER = {
  id: 1,
  email: "jaden@example.com",
  email_verified: false,
  nickname: "JadenYuki",
  age_group: "13-17",
  role: "player",
  level: 2,
  dp: 1234,
};
export const PASSWORD = "duelista123";
const TOKEN = "token-de-teste";

type Duel = { match_id: number; room_code: string | null };

// API de sessão falsa: lembra quem está logado e confere o token CSRF, como o Rails. duel é
// o duelo em andamento que o GET /api/session devolve.
export async function mockSession(
  page: Page,
  { loggedIn = false, duel = null }: { loggedIn?: boolean; duel?: Duel | null } = {},
) {
  let user: typeof PLAYER | null = loggedIn ? PLAYER : null;

  await page.route("**/api/session", async (route) => {
    const request = route.request();
    if (request.method() === "GET") {
      return route.fulfill({ json: { user, csrf_token: TOKEN, duel: user ? duel : null } });
    }
    if (request.headers()["x-csrf-token"] !== TOKEN) {
      return route.fulfill({
        status: 403,
        json: { error: { status: 403, message: "Página velha." } },
      });
    }
    if (request.method() === "DELETE") {
      user = null;
      return route.fulfill({ status: 204 });
    }
    if (request.postDataJSON().password !== PASSWORD) {
      return route.fulfill({
        status: 401,
        json: { error: { status: 401, message: "E-mail ou senha incorretos." } },
      });
    }
    user = PLAYER;
    return route.fulfill({ status: 201, json: { user } });
  });
}
