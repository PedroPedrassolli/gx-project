import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession } from "./support.ts";

const cards = [
  { id: 1, name: "Dark Magician", name_pt: "Mago Negro", card_type: "Monster", image: 46986414 },
  { id: 2, name: "Pot of Greed", name_pt: "Pote da Ganância", card_type: "Spell", image: 55144522 },
];
const shop = {
  balance: 120,
  level: 3,
  packs: [
    {
      id: 10,
      name: "Beginner Monsters",
      price: 50,
      cards_per_pack: 5,
      available: true,
      hint: null,
    },
    {
      id: 11,
      name: "Making the Team 1",
      price: 100,
      cards_per_pack: 5,
      available: false,
      hint: "Chegue ao nível 27.",
    },
  ],
};
const drawn = (id: number, rarity: string, isNew: boolean) => ({ id, rarity, new: isNew });

async function mockShop(page: Page) {
  await mockSession(page, { loggedIn: true });
  await page.route("**/api/cards", (route) => route.fulfill({ json: { data: cards } }));
  await page.route("**/api/packs", (route) => route.fulfill({ json: { data: [] } }));
  await page.route("**/api/shop", (route) => route.fulfill({ json: { data: shop } }));
  const sent: unknown[] = [];
  await page.route("**/api/shop/purchases", (route) => {
    sent.push(route.request().postDataJSON());
    const opening = [
      drawn(1, "ultra_rare", true),
      drawn(2, "common", true),
      drawn(2, "common", false),
      drawn(1, "ultra_rare", false),
      drawn(2, "common", false),
    ];
    return route.fulfill({ status: 201, json: { data: { balance: 70, openings: [opening] } } });
  });
  return sent;
}

test("sem login, pede para entrar", async ({ page }) => {
  await mockSession(page);
  await page.goto("/loja");

  await expect(page.getByRole("link", { name: "Entre na sua conta" })).toBeVisible();
});

test("a prateleira mostra o saldo, o preço e a dica dos bloqueados", async ({ page }) => {
  await mockShop(page);
  await page.goto("/loja");

  await expect(page.getByText("Você tem 120 DP. Nível 3.")).toBeVisible();
  const locked = page.getByRole("listitem").filter({ hasText: "Making the Team 1" });
  await expect(locked).toContainText("Chegue ao nível 27.");
  await expect(locked.getByRole("button")).toHaveCount(0);
  // 10 pacotes custam 500: o saldo não dá.
  await expect(page.getByRole("button", { name: "Comprar 10 (500 DP)" })).toBeDisabled();
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("comprar abre o pacote: as cartas aparecem uma por uma, com a raridade e as novas", async ({
  page,
}) => {
  const sent = await mockShop(page);
  await page.goto("/loja");
  await page.getByRole("button", { name: "Comprar 1", exact: true }).click();

  await expect(page.getByRole("heading", { name: "Beginner Monsters", level: 2 })).toBeVisible();
  await expect(page.getByRole("status").filter({ hasText: "cartas viradas" })).toHaveText(
    "0 de 5 cartas viradas.",
  );
  await page.getByRole("button", { name: "Virar a próxima" }).click();
  const first = page.getByRole("listitem").filter({ hasText: "Mago Negro" });
  await expect(first).toContainText("Ultra Rara");
  await expect(first).toContainText("Nova");
  await page.getByRole("button", { name: "Virar todas" }).click();
  await expect(page.getByRole("status").filter({ hasText: "cartas viradas" })).toHaveText(
    "5 de 5 cartas viradas.",
  );
  await expect(page.getByText("Nova")).toHaveCount(2);
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);

  await page.getByRole("button", { name: "Voltar para a loja" }).click();
  await expect(page.getByRole("button", { name: "Comprar 1", exact: true })).toBeVisible();
  expect(sent).toHaveLength(1);
  expect(sent[0]).toMatchObject({ pack_id: 10, count: 1 });
});
