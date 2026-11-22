import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession } from "./support.ts";

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
    // O detalhe de todas as cartas vem num pedido só (GXP-121); o de uma carta sozinha fica
    // para quando ele ainda não chegou.
    if (url.pathname === "/api/cards/details") {
      const { text, text_pt, packs, source, passcode } = detail;
      return route.fulfill({ json: { data: { 1: { text, text_pt, packs, source, passcode } } } });
    }
    if (url.pathname === "/api/cards/1") return route.fulfill({ json: { data: detail } });
    return route.fulfill({ status: 404, json: { error: { status: 404 } } });
  });
}

// Imagens simuladas: a do Pote da Ganância nunca carrega, para ver a face no lugar dela.
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
  await mockSession(page);
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
  // Sem filtro, não há o que limpar.
  await expect(page.getByRole("button", { name: "Limpar filtros" })).toBeDisabled();
  await page.getByRole("radio", { name: "Magia" }).check();
  await expect(page.getByRole("button", { name: /Pote da Ganância/ })).toContainText("Proibida");
  await page.getByRole("button", { name: "Limpar filtros" }).click();
  await page.getByRole("button", { name: /^Filtros/ }).click();
  const sheet = page.getByRole("dialog", { name: "Filtros" });
  await sheet.getByLabel("Pacote").selectOption({ label: "Beginner Monsters" });
  await sheet.getByRole("button", { name: "Ver 1 carta" }).click();
  await expect(page.getByRole("button", { name: /^Filtros\s*1$/ })).toBeVisible();
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

test("avisa quando o texto em português é tradução nossa, não a oficial", async ({ page }) => {
  const { text, text_pt, packs, source } = detail;
  const extra = { text, text_pt, packs, source, text_pt_unofficial: true };
  await page.route("**/api/cards/details", (route) =>
    route.fulfill({ json: { data: { 1: extra } } }),
  );
  await page.route("**/api/cards/1", (route) =>
    route.fulfill({ json: { data: { ...detail, ...extra } } }),
  );
  await page.goto("/cartas?carta=1");
  const panel = page.getByRole("region", { name: "Mago Negro" });
  await expect(panel).toContainText("O mago definitivo");
  await expect(panel).toContainText("Tradução não oficial, feita pelo GX Project.");
  await page.getByRole("radio", { name: "Inglês" }).check();
  await expect(page.getByRole("region", { name: "Dark Magician" })).not.toContainText(
    "Tradução não oficial",
  );
});

test("mostra a miniatura e a imagem da carta; sem imagem, a face com o nome", async ({ page }) => {
  await page.goto("/cartas?carta=1");
  // A conexão com o site das imagens abre junto com a página, antes de a lista chegar.
  await expect(
    page.locator('link[rel="preconnect"][href="https://gx-project-imagens.pages.dev"]'),
  ).toHaveCount(1);
  const thumb = page.getByRole("button", { name: /Mago Negro/ }).locator("img");
  await expect(thumb).toHaveAttribute("src", /\/cards\/m\/46986414\.webp$/);
  await expect(thumb).toHaveAttribute("loading", "lazy");
  await expect(page.getByRole("img", { name: "Imagem da carta Mago Negro" })).toBeVisible();
  // Por baixo da imagem grande, a que já veio com a grade aparece na hora.
  await expect(page.locator(".detail-image-thumb")).toHaveAttribute(
    "src",
    /\/cards\/m\/46986414\.webp$/,
  );
  // A que falha tenta de novo duas vezes e, sem jeito, vira a face da carta com o nome.
  const failed = page.getByRole("button", { name: /Pote da Ganância/ });
  await expect(failed.locator(".card-face")).toContainText("Pote da Ganância", { timeout: 8_000 });
  await expect(failed.locator("img")).toHaveCount(0);
  // A carta do anime, que não tem imagem, mostra a face desde o começo, também no detalhe.
  const anime = page.getByRole("button", { name: /Força Espelho/ });
  await expect(anime.locator("img")).toHaveCount(0);
  await expect(anime.locator(".card-face")).toContainText("Força Espelho");
  await anime.click();
  await expect(page.getByRole("img", { name: "Carta Força Espelho, sem imagem" })).toBeVisible();
});

test("imagem que falha uma vez tenta de novo e aparece", async ({ page }) => {
  let tries = 0;
  await page.route(/\/cards\/m\/46986414\.webp/, (route) => {
    tries += 1;
    return tries === 1 ? route.abort() : route.fulfill({ contentType: "image/png", body: PIXEL });
  });
  await page.goto("/cartas");

  const thumb = page.getByRole("button", { name: /Mago Negro/ }).locator("img");
  await expect(thumb).toHaveAttribute("src", /46986414\.webp\?tentativa=1$/);
  await expect(thumb).toBeVisible();
  await expect.poll(() => thumb.evaluate((image: HTMLImageElement) => image.naturalWidth)).toBe(1);
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

test("no celular, o detalhe abre por cima da lista e fecha no mesmo lugar", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/cartas");
  await page.getByRole("button", { name: /Mago Negro/ }).click();

  const dialog = page.getByRole("dialog", { name: "Mago Negro" });
  await expect(dialog).toContainText("O mago definitivo");
  await expect(dialog).toContainText("Beginner Monsters · Ultra Rara");
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);

  await dialog.getByRole("button", { name: "Fechar" }).click();
  await expect(dialog).toBeHidden();
  await expect(page).not.toHaveURL(/carta=/);
  await expect(page.getByRole("button", { name: /Mago Negro/ })).toBeInViewport();
});

test("na volta ao site, a lista e o texto vêm da cópia guardada, sem esperar o servidor", async ({
  page,
}) => {
  // Primeira visita: o catálogo e os textos chegam do servidor e ficam guardados.
  await page.goto("/cartas?carta=1");
  await expect(page.getByRole("region", { name: "Mago Negro" })).toContainText("O mago definitivo");
  await expect
    .poll(() => page.evaluate(async () => (await (await caches.open("gx-dados-v1")).keys()).length))
    .toBe(2);

  // Na volta, o servidor está acordando e não responde: a tela não espera por ele.
  await page.route(/\/api\/(cards|packs)/, () => undefined);
  await page.reload();
  await expect(page.getByRole("button", { name: /Mago Negro/ })).toBeVisible();
  await expect(page.getByRole("region", { name: "Mago Negro" })).toContainText("O mago definitivo");
});
