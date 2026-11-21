import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession } from "./support.ts";

const character = (
  id: string,
  name: string,
  position: number,
  group: [string, string],
  extra: Record<string, unknown>,
) => ({
  id,
  name,
  position,
  description: `O deck de ${name}.`,
  group: { id: group[0], name: group[1] },
  deck: `Deck de ${name}`,
  bonus: 60 * position,
  wins: 0,
  ...extra,
});

const ALUNOS: [string, string] = ["alunos", "Alunos da Academia"];
const LENDAS: [string, string] = ["lendas", "Lendas de Duel Monsters"];

const CHARACTERS = [
  character("chumley", "Chumley", 1, ALUNOS, {
    status: "beaten",
    wins: 2,
    signature: { id: 9, name: "Master of Oz", image: 27134689 },
  }),
  character("syrus", "Syrus", 2, ALUNOS, { status: "unlocked" }),
  character("yugi", "Yugi", 14, LENDAS, {
    status: "locked",
    unlock_hint: "Vença Kaiba para liberar.",
    signature: { id: 10, name: "Dark Magician", name_pt: "Mago Negro", image: 46986414 },
  }),
];

const DECKS = [
  {
    id: 3,
    name: "Deck inicial",
    updated_at: "2026-11-21T12:00:00Z",
    counts: { main: 40, extra: 0, side: 0 },
  },
  {
    id: 4,
    name: "Heróis",
    updated_at: "2026-11-21T12:00:00Z",
    counts: { main: 40, extra: 5, side: 0 },
  },
];

async function mockCharacters(page: Page, { current = null as number | null, decks = DECKS } = {}) {
  await page.route("**/api/characters", (route) =>
    route.fulfill({ json: { data: { characters: CHARACTERS, current_match_id: current } } }),
  );
  await page.route("**/api/decks", (route) => route.fulfill({ json: { data: decks } }));
}

test("sem login, pede para entrar", async ({ page }) => {
  await mockSession(page);
  await page.goto("/personagens");

  await expect(page.getByRole("link", { name: "Entre na sua conta" })).toBeVisible();
});

test("a lista em grupos, na ordem: vencido, liberado e bloqueado com a dica", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  await mockCharacters(page);
  await page.goto("/personagens");

  await expect(page.getByRole("heading", { level: 2 })).toHaveText([
    "Alunos da Academia",
    "Lendas de Duel Monsters",
  ]);
  const items = page.locator("ol.characters > li");
  await expect(items).toHaveCount(3);
  await expect(items.nth(0)).toContainText("Vencido 2 vezes");
  await expect(items.nth(0)).toContainText("Primeira vitória: a carta Master of Oz.");
  await expect(items.nth(1)).toContainText("Toda vitória: +120 DP.");
  await expect(page.getByRole("button", { name: "Duelar contra Syrus" })).toBeVisible();
  await expect(items.nth(2)).toContainText("Vença Kaiba para liberar.");
  await expect(page.getByRole("button", { name: "Duelar contra Yugi" })).toHaveCount(0);
  // O Yugi é o 14º da lista, mesmo no grupo dele.
  await expect(page.locator("ol.characters").nth(1)).toHaveAttribute("start", "14");
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("duelar abre o modal do deck e começa o duelo com o deck escolhido", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  await mockCharacters(page);
  let body: unknown = null;
  await page.route("**/api/characters/syrus/duels", (route) => {
    body = route.request().postDataJSON();
    return route.fulfill({ status: 201, json: { data: { match_id: 77 } } });
  });
  await page.route("**/api/matches/77", (route) =>
    route.fulfill({ status: 404, json: { error: { status: 404, message: "Não encontrado." } } }),
  );
  await page.goto("/personagens");

  await page.getByRole("button", { name: "Duelar contra Syrus" }).click();
  const dialog = page.getByRole("dialog", { name: "Duelar contra Syrus" });
  await expect(dialog).toContainText("Deck dele: Deck de Syrus.");
  await expect(page).toHaveURL(/duelar=syrus/);
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
  await dialog.getByLabel("Seu deck").selectOption("Heróis");
  await dialog.getByRole("button", { name: "Começar o duelo" }).click();

  await expect(page).toHaveURL(/\/duelo\/77$/);
  expect(body).toEqual({ deck_id: "4" });
  // O deck fica lembrado para a próxima vez.
  expect(await page.evaluate(() => localStorage.getItem("gx-deck-contra-personagens"))).toBe("4");
});

test("o motivo da recusa aparece no modal, e Cancelar fecha", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  await mockCharacters(page);
  await page.route("**/api/characters/chumley/duels", (route) =>
    route.fulfill({
      status: 422,
      json: {
        error: {
          status: 422,
          message: "Termine o duelo que está em andamento antes de começar outro.",
        },
      },
    }),
  );
  await page.goto("/personagens?duelar=chumley");

  const dialog = page.getByRole("dialog", { name: "Duelar contra Chumley" });
  await dialog.getByRole("button", { name: "Começar o duelo" }).click();
  await expect(dialog.getByRole("alert")).toHaveText(
    "Termine o duelo que está em andamento antes de começar outro.",
  );
  await dialog.getByRole("button", { name: "Cancelar" }).click();
  await expect(dialog).toBeHidden();
  await expect(page).toHaveURL(/\/personagens$/);
});

test("bloqueado não abre pelo endereço; sem deck, manda montar um", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  await mockCharacters(page, { decks: [] });
  await page.goto("/personagens?duelar=yugi");
  await expect(page.getByRole("heading", { name: "Personagens" })).toBeVisible();
  await expect(page.getByRole("dialog")).toHaveCount(0);

  await page.getByRole("button", { name: "Duelar contra Syrus" }).click();
  await expect(
    page.getByRole("dialog").getByRole("link", { name: "Monte um deck" }),
  ).toHaveAttribute("href", "/decks");
});

test("enquanto o jogador escolhe, o catálogo que a mesa usa já é buscado", async ({ page }) => {
  await mockCharacters(page);
  const catalog = page.waitForRequest(
    (request) => new URL(request.url()).pathname === "/api/cards",
  );
  await page.goto("/personagens");
  await catalog;
});

test("o duelo em andamento aparece com o caminho de volta", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  await mockCharacters(page, { current: 31 });
  await page.goto("/personagens");

  await expect(
    page.getByRole("main").getByRole("link", { name: "Voltar para a mesa" }),
  ).toHaveAttribute("href", "/duelo/31");
});
