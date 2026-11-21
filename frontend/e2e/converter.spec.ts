import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession } from "./support.ts";

const cards = [
  { id: 1, name: "Dark Magician", name_pt: "Mago Negro", card_type: "Monster", image: 46986414 },
  { id: 2, name: "Pot of Greed", name_pt: "Pote da Ganância", card_type: "Spell", image: 55144522 },
  { id: 3, name: "Trap Hole", name_pt: "Buraco Armadilha", card_type: "Trap", image: 4206964 },
];

async function mockConverter(
  page: Page,
  spare = [
    { card_id: 1, quantity: 7 },
    { card_id: 2, quantity: 5 },
  ],
) {
  await mockSession(page, { loggedIn: true });
  await page.route("**/api/cards", (route) => route.fulfill({ json: { data: cards } }));
  await page.route("**/api/packs", (route) => route.fulfill({ json: { data: [] } }));
  await page.route("**/api/shop/converter", (route) =>
    route.fulfill({ json: { data: { min: 10, max: 99, cards: spare } } }),
  );
  await page.route("**/api/shop/converter/groups/10", (route) =>
    route.fulfill({ json: { data: { amount: 10, cards: [3, 1] } } }),
  );
  const sent: unknown[] = [];
  await page.route("**/api/shop/conversions", (route) => {
    sent.push(route.request().postDataJSON());
    return route.fulfill({ status: 201, json: { data: { card_id: 3, amount: 10, new: true } } });
  });
  return sent;
}

test("sem login, pede para entrar", async ({ page }) => {
  await mockSession(page);
  await page.goto("/loja/conversor");

  await expect(page.getByRole("link", { name: "Entre na sua conta" })).toBeVisible();
});

test("escolhe as repetidas, vê o grupo da quantidade e converte", async ({ page }) => {
  const sent = await mockConverter(page);
  await page.goto("/loja/conversor");

  const items = page.locator("ul.converter-cards").getByRole("listitem");
  await expect(items).toHaveCount(2);
  await expect(items.first()).toContainText("Mago Negro7 repetidas");
  const convert = page.getByRole("button", { name: "Converter", exact: true });
  await expect(convert).toBeDisabled();

  await page.getByRole("button", { name: "Todas as 7 repetidas de Mago Negro" }).click();
  await expect(page.getByRole("status").filter({ hasText: "escolhidas" })).toHaveText(
    "7 cartas escolhidas. Faltam 3.",
  );
  for (let i = 0; i < 3; i++) {
    await page.getByRole("button", { name: "Uma a mais de Pote da Ganância" }).click();
  }
  await page.getByText("Ver as cartas que podem sair com 10").click();
  await expect(page.locator(".converter-group li")).toHaveText(["Buraco Armadilha", "Mago Negro"]);
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);

  await page.getByRole("button", { name: "Converter 10 cartas" }).click();
  await expect(page.getByRole("heading", { name: "Você trocou 10 cartas por:" })).toBeVisible();
  await expect(page.getByText("Buraco Armadilha")).toBeVisible();
  await expect(page.getByText("Nova")).toBeVisible();
  expect(sent).toHaveLength(1);
  expect(sent[0]).toMatchObject({
    cards: [
      { id: 1, quantity: 7 },
      { id: 2, quantity: 3 },
    ],
  });

  await page.getByRole("button", { name: "Converter de novo" }).click();
  await expect(page.getByRole("button", { name: "Converter", exact: true })).toBeDisabled();
});

test("sem repetidas, manda para a loja; a loja leva ao conversor", async ({ page }) => {
  await mockConverter(page, []);
  await page.route("**/api/shop", (route) =>
    route.fulfill({ json: { data: { balance: 0, level: 1, packs: [] } } }),
  );
  await page.goto("/loja");
  await page.getByRole("link", { name: "Abrir o conversor" }).click();

  await expect(page).toHaveURL("/loja/conversor");
  await expect(page.getByText("Você ainda não tem cartas repetidas para trocar.")).toBeVisible();
});
