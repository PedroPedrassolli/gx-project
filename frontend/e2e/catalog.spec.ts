import { expect, test, type Page } from "@playwright/test";
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
    image: 46986414,
  },
  {
    id: 2,
    name: "Pot of Greed",
    name_pt: "Pote da Ganância",
    card_type: "Spell",
    property: "Normal",
    banlist: "forbidden",
    image: 55144522,
  },
  { id: 3, name: "Mirror Force", name_pt: "Força Espelho", card_type: "Trap", property: "Normal" },
];
const detail = {
  ...cards[0],
  passcode: 46986414,
  text: "The ultimate wizard in terms of attack and defense.",
  text_pt: "O mago definitivo em termos de ataque e defesa.",
  packs: [{ id: 7, rarity: "ultra_rare" }],
  source: "https://yugipedia.com/index.php?oldid=1",
};
const packs = [{ id: 7, name: "Beginner Monsters", position: 1, card_count: 1 }];

async function mockApi(page: Page) {
  await page.route("**/api/**", async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/api/packs") return route.fulfill({ json: { data: packs } });
    if (url.pathname === "/api/cards") {
      const data = url.searchParams.get("pack") ? [{ ...cards[0], rarity: "ultra_rare" }] : cards;
      return route.fulfill({ json: { data } });
    }
    if (url.pathname === "/api/cards/1") return route.fulfill({ json: { data: detail } });
    return route.fulfill({ status: 404, json: { error: { status: 404 } } });
  });
}

// Imagens simuladas: a do Pote da Ganância não carrega, para ver que ela some.
const PIXEL = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=",
  "base64",
);

async function mockImages(page: Page) {
  await page.route(/\.pages\.dev\//, (route) =>
    route.request().url().includes("/55144522.")
      ? route.abort()
      : route.fulfill({ contentType: "image/png", body: PIXEL }),
  );
}

test.beforeEach(async ({ page }) => {
  await mockApi(page);
  await mockImages(page);
});

test("lista as cartas e busca pelo nome em português", async ({ page }) => {
  await page.goto("/cartas");
  await expect(page.getByRole("status")).toHaveText("3 cartas");
  await page.getByLabel("Nome").fill("mago");
  await expect(page.getByRole("status")).toHaveText("1 carta");
  await expect(page.getByRole("button", { name: /Mago Negro/ })).toBeVisible();
});

test("filtra pelo tipo de carta e pelo pacote, com a raridade", async ({ page }) => {
  await page.goto("/cartas");
  await page.getByRole("radio", { name: "Magia" }).check();
  await expect(page.getByRole("button", { name: /Pote da Ganância/ })).toContainText("Proibida");
  await page.getByRole("button", { name: "Limpar filtros" }).click();
  await page.getByText("Mais filtros").click();
  await page.getByLabel("Pacote").selectOption({ label: "Beginner Monsters" });
  await expect(page.getByRole("status")).toHaveText("1 carta");
  await expect(page.getByRole("button", { name: /Mago Negro/ })).toContainText("Ultra Rara");
});

test("mostra o detalhe da carta e troca o idioma do texto", async ({ page }) => {
  await page.goto("/cartas");
  await page.getByRole("button", { name: /Mago Negro/ }).click();
  const panel = page.getByRole("region", { name: "Mago Negro" });
  await expect(panel).toContainText("O mago definitivo");
  await expect(panel).toContainText("Beginner Monsters · Ultra Rara");
  await expect(page).toHaveURL(/carta=1/);
  await page.getByRole("radio", { name: "Inglês" }).check();
  await expect(page.getByRole("region", { name: "Dark Magician" })).toContainText(
    "The ultimate wizard",
  );
});

test("mostra a miniatura e a imagem da carta, e esconde a que não carrega", async ({ page }) => {
  await page.goto("/cartas?carta=1");
  const thumb = page.getByRole("button", { name: /Mago Negro/ }).locator("img");
  await expect(thumb).toHaveAttribute("src", /\/cards\/p\/46986414\.webp$/);
  await expect(thumb).toHaveAttribute("loading", "lazy");
  await expect(page.getByRole("img", { name: "Imagem da carta Mago Negro" })).toBeVisible();
  await expect(page.getByRole("button", { name: /Pote da Ganância/ }).locator("img")).toBeHidden();
  await expect(page.getByRole("button", { name: /Força Espelho/ }).locator("img")).toHaveCount(0);
});

test("abre pelo link da carta e avisa quando ela não existe", async ({ page }) => {
  await page.goto("/cartas?carta=99");
  await expect(page.getByRole("heading", { name: "Carta não encontrada." })).toBeVisible();
});

test("avisa quando a API falha", async ({ page }) => {
  await page.route("**/api/cards", (route) => route.fulfill({ status: 500, body: "erro" }));
  await page.goto("/cartas");
  await expect(page.getByRole("alert")).toHaveText("Não deu para carregar as cartas.");
});

test("o catálogo com uma carta aberta passa no axe sem violações", async ({ page }) => {
  await page.goto("/cartas?carta=1");
  await expect(page.getByRole("region", { name: "Mago Negro" })).toBeVisible();
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});
