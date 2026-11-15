import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession, PLAYER } from "./support.ts";

type Room = {
  code: string;
  public: boolean;
  mode: string;
  best_of: number;
  banlist: boolean;
  destiny_draw: boolean;
  status: string;
  owner_id: number;
  seats: number;
  players: Record<string, unknown>[];
};

const ME = { seat: 0, user_id: PLAYER.id, nickname: "JadenYuki", ready: false, deck_chosen: false };
const ROOM: Room = {
  code: "ABC234",
  public: true,
  mode: "1x1",
  best_of: 1,
  banlist: true,
  destiny_draw: true,
  status: "waiting",
  owner_id: PLAYER.id,
  seats: 2,
  players: [ME],
};

// API falsa das salas, sem tempo real (o token responde 503): a tela consulta a sala.
async function mockRoom(page: Page, room: Room = ROOM) {
  let current: Room = structuredClone(room);
  await page.route("**/api/realtime/token", (route) =>
    route.fulfill({
      status: 503,
      json: { error: { status: 503, message: "O tempo real está desligado." } },
    }),
  );
  await page.route("**/api/rooms/ABC234", (route) => route.fulfill({ json: { data: current } }));
  await page.route("**/api/rooms/ABC234/join", (route) => {
    current = { ...current, players: [...current.players, { ...ME, seat: 1 }] };
    return route.fulfill({ json: { data: current } });
  });
  await page.route("**/api/rooms/ABC234/leave", (route) => route.fulfill({ status: 204 }));
  return { set: (next: Room) => (current = next) };
}

test.beforeEach(async ({ page }) => mockSession(page, { loggedIn: true }));

test("mostra os lugares, as opções e quem criou a sala", async ({ page }) => {
  await mockRoom(page);
  await page.goto("/salas/abc234");

  await expect(page.getByRole("heading", { level: 1, name: "Sala ABC234" })).toBeVisible();
  const seats = page.getByRole("list", { name: "Lugares" });
  await expect(seats.getByRole("listitem").first()).toContainText("JadenYuki");
  await expect(seats.getByRole("listitem").first()).toContainText("Criou a sala");
  await expect(seats.getByRole("listitem").nth(1)).toHaveText("Vaga livre");
  await expect(page.getByText("Banlist do jogo")).toBeVisible();
  await expect(page.getByRole("status").filter({ hasText: "a cada 2 segundos" })).toBeVisible();

  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("sem tempo real, quem chega aparece na próxima consulta", async ({ page }) => {
  const room = await mockRoom(page);
  await page.goto("/salas/ABC234");
  await expect(page.getByText("Vaga livre")).toBeVisible();

  room.set({
    ...ROOM,
    players: [ME, { seat: 1, user_id: 2, nickname: "Syrus", ready: true, deck_chosen: true }],
  });
  const seats = page.getByRole("list", { name: "Lugares" });
  await expect(seats.getByRole("listitem").nth(1)).toContainText("Syrus", { timeout: 5000 });
  await expect(seats.getByRole("listitem").nth(1)).toContainText("Pronto");
});

test("quem abre o link de uma sala entra nela", async ({ page }) => {
  await mockRoom(page, {
    ...ROOM,
    owner_id: 2,
    players: [{ ...ME, user_id: 2, nickname: "Syrus" }],
  });
  await page.goto("/salas/ABC234");
  await page.getByRole("button", { name: "Entrar na sala" }).click();

  await expect(page.getByRole("heading", { name: "Seu deck" })).toBeVisible();
  await page.getByRole("button", { name: "Sair da sala" }).click();
  await expect(page).toHaveURL("/salas");
});

test("sala que não existe avisa", async ({ page }) => {
  await mockRoom(page);
  await page.route("**/api/rooms/ZZZ999", (route) =>
    route.fulfill({ status: 404, json: { error: { status: 404, message: "Não encontrado." } } }),
  );
  await page.goto("/salas/ZZZ999");

  await expect(page.getByRole("alert")).toHaveText(
    "Não achamos esta sala. Confira o código ou crie outra.",
  );
});
