import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

// A API é simulada: o "vite preview" só serve o front.
const cards = [
  {
    id: 1,
    name: "Dark Magician",
    name_pt: "Mago Negro",
    card_type: "Monster",
    attribute: "DARK",
    race: "Spellcaster",
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
  { id: 3, name: "Mirror Force", name_pt: "Força Espelho", card_type: "Trap", property: "Normal" },
];

test.beforeEach(async ({ page }) => {
  await page.route("**/api/cards", (route) => route.fulfill({ json: { data: cards } }));
});

test("lista as cartas e busca pelo nome em português", async ({ page }) => {
  await page.goto("/cartas");
  await expect(page.getByRole("status")).toHaveText("3 cartas");
  await page.getByLabel("Nome").fill("mago");
  await expect(page.getByRole("status")).toHaveText("1 carta");
  await expect(page.getByRole("listitem")).toContainText("Mago Negro");
  await expect(page.getByRole("listitem")).toContainText("Mago / Normal");
});

test("filtra pelo tipo de carta e mostra a banlist", async ({ page }) => {
  await page.goto("/cartas");
  await page.getByRole("radio", { name: "Magia" }).check();
  await expect(page.getByRole("status")).toHaveText("1 carta");
  await expect(page.getByRole("listitem")).toContainText("Pote da Ganância");
  await expect(page.getByRole("listitem")).toContainText("Proibida");
});

test("avisa quando a API falha", async ({ page }) => {
  await page.route("**/api/cards", (route) => route.fulfill({ status: 500, body: "erro" }));
  await page.goto("/cartas");
  await expect(page.getByRole("alert")).toHaveText("Não deu para carregar as cartas.");
});

test("o catálogo passa no axe sem violações", async ({ page }) => {
  await page.goto("/cartas");
  await expect(page.getByRole("status")).toHaveText("3 cartas");
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});
