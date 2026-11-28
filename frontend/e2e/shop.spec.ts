import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession } from "./support.ts";

const cards = [
  { id: 1, name: "Dark Magician", name_pt: "Mago Negro", card_type: "Monster", image: 46986414 },
  { id: 2, name: "Pot of Greed", name_pt: "Pote da Ganância", card_type: "Spell", image: 55144522 },
  // Carta do anime: a imagem é a da Yugipedia, publicada pelo código da engine (GXP-142).
  { id: 3, name: "Clear World", name_pt: "Mundo Claro", card_type: "Spell", image: 511000306 },
];
const PIXEL = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=",
  "base64",
);
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
      new: true,
    },
    {
      id: 11,
      name: "Making the Team 1",
      price: 100,
      cards_per_pack: 5,
      available: false,
      hint: "Chegue ao nível 27.",
      progress: 11,
      new: false,
    },
  ],
};
// A capa de cada pacote vem do catálogo: a carta mais rara dele que tem imagem.
const packs = [
  { id: 10, name: "Beginner Monsters", position: 1, card_count: 3, cover: 1 },
  { id: 11, name: "Making the Team 1", position: 2, card_count: 3, cover: 2 },
];
const drawn = (id: number, rarity: string, isNew: boolean) => ({ id, rarity, new: isNew });
// A última carta de cada pacote é a de raridade aumentada: rara ou melhor, e vem marcada.
const opening = [
  drawn(1, "ultra_rare", true),
  drawn(2, "common", true),
  drawn(2, "common", false),
  drawn(3, "common", false),
  { ...drawn(1, "ultra_rare", false), rare_slot: true },
];

// Os pedidos de imagem que a página fez (as imagens são simuladas). failFirst: o primeiro
// pedido de cada imagem falha, e a nova tentativa (?tentativa=1) dá certo.
async function mockShop(page: Page, images: string[] = [], failFirst = false) {
  await page.route(/\.pages\.dev\//, (route) => {
    const url = new URL(route.request().url());
    images.push(url.pathname);
    if (failFirst && !url.search.includes("tentativa")) return route.abort();
    return route.fulfill({ contentType: "image/png", body: PIXEL });
  });
  await mockSession(page, { loggedIn: true });
  await page.route("**/api/cards", (route) => route.fulfill({ json: { data: cards } }));
  await page.route("**/api/packs", (route) => route.fulfill({ json: { data: packs } }));
  await page.route("**/api/shop", (route) => route.fulfill({ json: { data: shop } }));
  await page.route("**/api/shop/seen", (route) => route.fulfill({ status: 204 }));
  const sent: unknown[] = [];
  await page.route("**/api/shop/purchases", (route) => {
    const body = route.request().postDataJSON() as { count: number };
    sent.push(body);
    const openings = Array.from({ length: body.count }, () => opening);
    return route.fulfill({ status: 201, json: { data: { balance: 70, openings } } });
  });
  return sent;
}

test("sem login, pede para entrar", async ({ page }) => {
  await mockSession(page);
  await page.goto("/loja");

  await expect(page.getByRole("link", { name: "Entre na sua conta" })).toBeVisible();
});

test("a prateleira mostra a capa, o saldo, o preço, o selo de novo e o caminho dos bloqueados", async ({
  page,
}) => {
  await mockShop(page);
  const seen = page.waitForRequest("**/api/shop/seen");
  await page.goto("/loja");

  await expect(page.getByText("Você tem 120 DP. Nível 3.")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Beginner Monsters Novo" })).toBeVisible();
  await seen;
  const open = page.getByRole("listitem").filter({ hasText: "Beginner Monsters" });
  await expect(open.locator(".pack-cover img")).toHaveAttribute("src", /46986414/);
  const locked = page.getByRole("listitem").filter({ hasText: "Making the Team 1" });
  await expect(locked).toContainText("Chegue ao nível 27.");
  await expect(
    locked.getByRole("progressbar", { name: "Caminho para liberar Making the Team 1" }),
  ).toHaveAttribute("value", "11");
  await expect(locked).toContainText("11%");
  await expect(locked).not.toContainText("Novo");
  await expect(locked.getByRole("button")).toHaveCount(0);
  // 10 pacotes custam 500: o saldo não dá, e a prateleira diz quanto falta.
  await expect(page.getByRole("button", { name: "Comprar 10 (500 DP)" })).toBeDisabled();
  await expect(page.getByText("Faltam 380 DP para comprar 10.")).toBeVisible();
  await expect(page.getByRole("button", { name: "Comprar 1", exact: true })).toBeEnabled();
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("comprar abre o pacote em tela cheia: a mais rara no meio e as outras para virar", async ({
  page,
}) => {
  const images: string[] = [];
  const sent = await mockShop(page, images);
  await page.goto("/loja");
  await page.getByRole("button", { name: "Comprar 1", exact: true }).click();

  const dialog = page.getByRole("dialog", { name: "Beginner Monsters" });
  await expect(dialog).toBeVisible();
  const status = dialog.getByRole("status");
  await expect(status).toHaveText("0 de 5 cartas viradas.");
  // As imagens do pacote baixam antes de virar: a carta aparece pronta.
  await expect
    .poll(() => images)
    .toEqual(expect.arrayContaining(["/cards/m/46986414.webp", "/cards/m/55144522.webp"]));
  // A carta de raridade aumentada (a última) vai para o meio e já avisa, ainda virada.
  const featured = dialog.getByRole("listitem").last();
  await expect(featured).toHaveClass(/featured/);
  await expect(featured).toContainText("Rara ou melhor");
  await dialog.getByRole("button", { name: "Virar a carta 1" }).click();
  const first = dialog.getByRole("listitem").first();
  await expect(first.getByRole("img", { name: "Mago Negro" })).toBeVisible();
  await expect(first).toContainText("Ultra Rara");
  await expect(first).toContainText("Nova");
  // O foco segue para a próxima carta virada: dá para abrir tudo no Enter.
  await expect(dialog.getByRole("button", { name: "Virar a carta 2" })).toBeFocused();

  await dialog.getByRole("button", { name: "Virar todas" }).click();
  await expect(status).toHaveText("5 de 5 cartas viradas.");
  await expect(featured).toContainText("Mago Negro");
  await expect(dialog.getByText("Nova")).toHaveCount(2);
  // A carta do anime também vem com a imagem.
  await expect(dialog.getByRole("img", { name: "Mundo Claro" })).toHaveAttribute(
    "src",
    /511000306/,
  );
  await expect(dialog).toContainText("Saldo: 70 DP.");
  await expect(dialog.getByRole("button", { name: "Abrir outro (50 DP)" })).toBeFocused();
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);

  // "Abrir outro" compra mais um do mesmo pacote, ali mesmo.
  await dialog.getByRole("button", { name: "Abrir outro (50 DP)" }).click();
  await expect(status).toHaveText("0 de 5 cartas viradas.");
  expect(sent).toHaveLength(2);
  expect(sent[1]).toMatchObject({ pack_id: 10, count: 1 });

  await dialog.getByRole("button", { name: "Fechar o pacote" }).click();
  await expect(dialog).toBeHidden();
  await expect(page.getByRole("button", { name: "Comprar 1", exact: true })).toBeVisible();
});

test("a imagem que falha dá lugar ao verso da carta na hora e volta na nova tentativa", async ({
  page,
}) => {
  await mockShop(page, [], true);
  await page.goto("/loja");
  await page.getByRole("button", { name: "Comprar 1", exact: true }).click();
  const dialog = page.getByRole("dialog");
  await dialog.getByRole("button", { name: "Virar a carta 2" }).click();
  const card = dialog.getByRole("listitem").nth(1);

  // Sem esperar as novas tentativas: o verso aparece logo, com o nome para o leitor de tela.
  await expect(card.getByRole("img", { name: "Pote da Ganância" })).toHaveClass(
    /card-placeholder/,
    { timeout: 700 },
  );
  // A nova tentativa dá certo e a imagem volta no lugar.
  await expect(card.locator("img")).toHaveAttribute("src", /tentativa=1/);
  await expect(card.locator(".card-placeholder")).toHaveCount(0);
});

test("enquanto o catálogo não chega, as cartas viradas esperam fechadas", async ({ page }) => {
  await mockShop(page);
  let release = () => {};
  const arrived = new Promise<void>((resolve) => (release = resolve));
  await page.route("**/api/cards", async (route) => {
    await arrived;
    await route.fulfill({ json: { data: cards } });
  });
  await page.goto("/loja");
  await page.getByRole("button", { name: "Comprar 1", exact: true }).click();
  const dialog = page.getByRole("dialog");
  await dialog.getByRole("button", { name: "Virar todas" }).click();

  await expect(dialog.getByText("Carregando as cartas…")).toBeVisible();
  await expect(dialog.locator(".card-placeholder, .face img")).toHaveCount(0);
  release();
  await expect(dialog.getByRole("status")).toHaveText("5 de 5 cartas viradas.");
  await expect(dialog.getByRole("img", { name: "Mago Negro" }).first()).toBeVisible();
});

test("comprar 10 abre um pacote por vez, cada um com as 5 cartas dele", async ({ page }) => {
  await mockShop(page);
  await page.route("**/api/shop", (route) =>
    route.fulfill({ json: { data: { ...shop, balance: 1000 } } }),
  );
  await page.goto("/loja");
  await page.getByRole("button", { name: "Comprar 10 (500 DP)" }).click();

  const dialog = page.getByRole("dialog");
  const status = dialog.getByRole("status");
  const cardsOfPack = dialog.getByRole("list", { name: "Cartas do pacote" }).getByRole("listitem");
  for (let number = 1; number <= 10; number++) {
    await expect(
      dialog.getByRole("heading", { name: `Pacote ${number} de 10: Beginner Monsters` }),
    ).toBeVisible();
    await expect(status).toHaveText("0 de 5 cartas viradas.");
    await expect(cardsOfPack).toHaveCount(5);
    await expect(dialog.getByText("Rara ou melhor")).toHaveCount(1);
    await dialog.getByRole("button", { name: "Virar todas" }).click();
    await expect(status).toHaveText("5 de 5 cartas viradas.");
    if (number < 10) {
      // O botão principal vira "abrir o próximo" no mesmo lugar: dá para seguir só no Enter.
      const next = dialog.getByRole("button", { name: "Abrir o próximo pacote" });
      await expect(next).toBeFocused();
      await next.click();
    }
  }
  await expect(dialog.getByRole("button", { name: "Abrir o próximo pacote" })).toHaveCount(0);
  // No último, "Abrir outro" compra mais um (o saldo depois da compra é 70; o pacote, 50).
  await expect(dialog.getByRole("button", { name: "Abrir outro (50 DP)" })).toBeEnabled();
  await page.keyboard.press("Escape");
  await expect(dialog).toBeHidden();
  await expect(page.getByRole("button", { name: "Comprar 1", exact: true })).toBeVisible();
});

test("sem DP para mais um, Abrir outro desativa e diz quanto falta", async ({ page }) => {
  await mockShop(page);
  await page.route("**/api/shop/purchases", (route) =>
    route.fulfill({ status: 201, json: { data: { balance: 20, openings: [opening] } } }),
  );
  await page.goto("/loja");
  await page.getByRole("button", { name: "Comprar 1", exact: true }).click();

  const dialog = page.getByRole("dialog", { name: "Beginner Monsters" });
  await dialog.getByRole("button", { name: "Virar todas" }).click();
  await expect(dialog.getByRole("button", { name: "Abrir outro (50 DP)" })).toBeDisabled();
  await expect(dialog).toContainText("Faltam 30 DP para abrir outro.");
});

test("o código secreto se monta nos botões e libera o pacote", async ({ page }) => {
  await mockShop(page);
  const sent: unknown[] = [];
  await page.route("**/api/shop/codes", (route) => {
    const body = route.request().postDataJSON();
    sent.push(body);
    if (body.code === "↑↓") {
      return route.fulfill({ status: 201, json: { data: { packs: ["Midday Constellation"] } } });
    }
    return route.fulfill({
      status: 422,
      json: { error: { status: 422, message: "Esse código não libera nada." } },
    });
  });
  await page.goto("/loja");

  const send = page.getByRole("button", { name: "Enviar o código" });
  await expect(send).toBeDisabled();
  await page.getByRole("button", { name: "Xis" }).click();
  await send.click();
  await expect(page.getByRole("alert")).toHaveText("Esse código não libera nada.");
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);

  await page.getByRole("button", { name: "Apagar" }).click();
  await page.getByRole("button", { name: "Cima" }).click();
  await page.getByRole("button", { name: "Baixo" }).click();
  await expect(page.getByLabel("Código digitado")).toHaveText("↑↓");
  await send.click();
  await expect(page.getByText("Pacote liberado: Midday Constellation.")).toBeVisible();
  await expect(page.getByLabel("Código digitado")).toHaveText("…");
  expect(sent).toEqual([{ code: "×" }, { code: "↑↓" }]);
});
