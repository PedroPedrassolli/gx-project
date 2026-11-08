import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession } from "./support.ts";

const cards = [
  {
    id: 1,
    name: "Dark Magician",
    name_pt: "Mago Negro",
    card_type: "Monster",
    monster_types: ["Normal"],
    level: 7,
    atk: 2500,
    def: 2100,
  },
  {
    id: 2,
    name: "Pot of Greed",
    name_pt: "Pote da Ganância",
    card_type: "Spell",
    property: "Normal",
    banlist: "forbidden",
  },
  {
    id: 3,
    name: "Elemental HERO Flame Wingman",
    card_type: "Monster",
    monster_types: ["Fusion", "Effect"],
    level: 6,
    atk: 2100,
    def: 1200,
  },
];
const deck = {
  id: 7,
  name: "Heróis",
  updated_at: "2026-11-08T12:00:00.000-03:00",
  cards: [
    { card_id: 1, section: "main", quantity: 2, destiny: false },
    { card_id: 2, section: "main", quantity: 1, destiny: false },
    { card_id: 3, section: "extra", quantity: 1, destiny: false },
  ],
  valid: false,
  errors: [],
};
const collection = {
  data: [1, 2, 3].map((card_id) => ({
    card_id,
    quantity: card_id === 1 ? 3 : 1,
    obtained_at: "2026-11-08T12:00:00.000-03:00",
  })),
  meta: { total: { owned: 3, cards: 3, percent: 100 }, packs: [] },
};

async function mockDeckApi(page: Page) {
  await mockSession(page, { loggedIn: true });
  await page.route("**/api/cards", (route) =>
    route.fulfill({ json: { data: cards, meta: { total: 3 } } }),
  );
  await page.route("**/api/packs", (route) => route.fulfill({ json: { data: [] } }));
  await page.route("**/api/collection", (route) => route.fulfill({ json: collection }));
  await page.route("**/api/decks/7", (route) => {
    if (route.request().method() === "GET") return route.fulfill({ json: { data: deck } });
    const body = route.request().postDataJSON();
    return route.fulfill({ json: { data: { ...deck, name: body.name, cards: body.cards } } });
  });
  await page.route("**/api/decks/99", (route) =>
    route.fulfill({ status: 404, json: { error: { status: 404, message: "Não encontrado." } } }),
  );
}

test.beforeEach(async ({ page }) => mockDeckApi(page));

test("mostra o deck por seção e valida ao vivo", async ({ page }) => {
  await page.goto("/decks/7");

  await expect(page.getByRole("heading", { level: 1, name: "Heróis" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Main Deck (3)" })).toHaveAttribute(
    "aria-pressed",
    "true",
  );
  const problems = page.getByRole("list", { name: "Problemas do deck" });
  await expect(problems).toContainText("O Main Deck precisa ter de 40 a 60 cartas (tem 3).");
  await expect(problems).toContainText("Pote da Ganância está proibida.");

  await page.getByRole("button", { name: "Pôr mais uma cópia de Mago Negro" }).click();
  await expect(page.getByRole("button", { name: "Main Deck (4)" })).toBeVisible();
  await expect(problems).toContainText("(tem 4)");

  await page.getByRole("button", { name: "Extra Deck (1)" }).click();
  await expect(page.getByRole("list", { name: "Extra Deck" })).toContainText(
    "1× Elemental HERO Flame Wingman",
  );

  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("marca Destiny, manda uma cópia para o Side e salva", async ({ page }) => {
  let saved: { name: string; cards: unknown[] } | undefined;
  page.on("request", (request) => {
    if (request.method() === "PATCH") saved = request.postDataJSON();
  });
  await page.goto("/decks/7");
  await page.getByLabel("Nome do deck").fill("Heróis do Jaden");
  await page.getByRole("listitem").filter({ hasText: "Mago Negro" }).getByLabel("Destiny").check();
  await page
    .getByRole("listitem")
    .filter({ hasText: "Mago Negro" })
    .getByRole("button", { name: "Uma para o Side" })
    .click();
  await page.getByRole("button", { name: "Salvar" }).click();

  await expect(page.getByRole("status").filter({ hasText: "Deck salvo." })).toBeVisible();
  expect(saved?.name).toBe("Heróis do Jaden");
  expect(saved?.cards).toEqual([
    { card_id: 1, section: "main", quantity: 1, destiny: true },
    { card_id: 2, section: "main", quantity: 1, destiny: false },
    { card_id: 3, section: "extra", quantity: 1, destiny: false },
    { card_id: 1, section: "side", quantity: 1, destiny: false },
  ]);
});

test("avisa do deck que não existe", async ({ page }) => {
  await page.goto("/decks/99");

  await expect(page.getByRole("heading", { level: 1, name: "Deck não encontrado" })).toBeVisible();
});
