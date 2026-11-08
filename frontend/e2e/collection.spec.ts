import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession } from "./support.ts";

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
  },
  { id: 3, name: "Mirror Force", name_pt: "Força Espelho", card_type: "Trap", property: "Normal" },
];
const collection = {
  data: [
    { card_id: 1, quantity: 2, obtained_at: "2026-11-08T12:00:00.000-03:00" },
    { card_id: 3, quantity: 1, obtained_at: "2026-11-08T12:00:00.000-03:00" },
  ],
  meta: {
    total: { owned: 2, cards: 3, percent: 66.7 },
    packs: [{ id: 10, owned: 1, cards: 2, percent: 50.0 }],
  },
};

test("sem login, pede para entrar", async ({ page }) => {
  await mockSession(page);
  await page.goto("/colecao");

  await expect(page.getByRole("link", { name: "Entre na sua conta" })).toHaveAttribute(
    "href",
    "/entrar",
  );
});

test("mostra só as cartas do jogador, com as cópias e o progresso", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  await page.route("**/api/cards", (route) =>
    route.fulfill({ json: { data: cards, meta: { total: 3 } } }),
  );
  await page.route("**/api/packs", (route) =>
    route.fulfill({ json: { data: [{ id: 10, name: "Pack A" }] } }),
  );
  await page.route("**/api/collection", (route) => route.fulfill({ json: collection }));
  await page.goto("/");
  await page
    .getByRole("navigation", { name: "Principal" })
    .getByRole("link", { name: "Coleção" })
    .click();

  await expect(
    page.getByRole("heading", { level: 2, name: "Você tem 2 de 3 (66,7%) cartas do jogo" }),
  ).toBeVisible();
  const results = page.getByRole("region", { name: "Cartas da coleção" });
  await expect(results.getByRole("status")).toHaveText("2 cartas");
  await expect(results.getByRole("button", { name: /Mago Negro/ })).toContainText("2 cópias");
  await expect(results.getByRole("button", { name: /Força Espelho/ })).toContainText("1 cópia");
  await expect(results.getByRole("button", { name: /Pote da Ganância/ })).toHaveCount(0);

  await page.getByText("Por pacote").click();
  await expect(page.getByRole("listitem").filter({ hasText: "Pack A" })).toHaveText(
    "Pack A 1 de 2 (50%)",
  );

  const axe = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(axe.violations).toEqual([]);
});
