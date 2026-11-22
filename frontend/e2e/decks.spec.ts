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
  { id: 4, name: "Mirror Force", name_pt: "Força Espelho", card_type: "Trap", property: "Normal" },
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
  // A 3 veio depois, de um pacote, e o jogador ainda não viu.
  data: [1, 2, 3].map((card_id) => ({
    card_id,
    quantity: card_id === 1 ? 3 : 1,
    obtained_at: card_id === 3 ? "2026-11-20T21:00:00.000-03:00" : "2026-11-08T12:00:00.000-03:00",
    new: card_id === 3,
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
    if (route.request().method() === "DELETE") return route.fulfill({ status: 204 });
    const body = route.request().postDataJSON();
    return route.fulfill({ json: { data: { ...deck, name: body.name, cards: body.cards } } });
  });
  await page.route("**/api/decks", (route) => {
    if (route.request().method() === "GET") {
      return route.fulfill({
        json: {
          data: [
            {
              id: 7,
              name: "Heróis",
              updated_at: deck.updated_at,
              counts: { main: 3, extra: 1 },
            },
          ],
        },
      });
    }
    return route.fulfill({ status: 201, json: { data: deck } });
  });
  await page.route("**/api/decks/import", (route) =>
    route.fulfill({
      status: 201,
      json: { data: deck, meta: { warnings: ["O código 12345 não está no pool."] } },
    }),
  );
  await page.route("**/api/cards/1", (route) =>
    route.fulfill({
      json: {
        data: { ...cards[0], text: "The ultimate wizard.", source: "https://yugipedia.com" },
      },
    }),
  );
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

test("marca Destiny, tira uma cópia e salva", async ({ page }) => {
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
    .getByRole("button", { name: "Tirar uma cópia de Mago Negro" })
    .click();
  await page.getByRole("button", { name: "Salvar" }).click();

  await expect(page.getByRole("status").filter({ hasText: "Deck salvo." })).toBeVisible();
  expect(saved?.name).toBe("Heróis do Jaden");
  expect(saved?.cards).toEqual([
    { card_id: 1, section: "main", quantity: 1, destiny: true },
    { card_id: 2, section: "main", quantity: 1, destiny: false },
    { card_id: 3, section: "extra", quantity: 1, destiny: false },
  ]);
});

test("avisa do deck que não existe", async ({ page }) => {
  await page.goto("/decks/99");

  await expect(page.getByRole("heading", { level: 1, name: "Deck não encontrado" })).toBeVisible();
});

test("lista os decks pela barra do topo e cria um novo", async ({ page }) => {
  await page.goto("/");
  await page
    .getByRole("navigation", { name: "Principal" })
    .getByRole("link", { name: "Decks" })
    .click();

  await expect(page.getByRole("listitem").filter({ hasText: "Heróis" })).toContainText(
    "Main 3 Extra 1",
  );
  await page.getByRole("button", { name: "Criar deck novo" }).click();
  await expect(page).toHaveURL("/decks/7");
});

test("importa uma lista e mostra o que ficou de fora", async ({ page }) => {
  await page.goto("/decks");
  await page.getByLabel("Formato").selectOption("ydk");
  await page.getByLabel("Lista do deck").fill("#main\n46986414\n12345\n");
  await page.getByRole("button", { name: "Importar" }).click();

  await expect(page.getByRole("region", { name: "Ficou de fora da importação" })).toContainText(
    "O código 12345 não está no pool.",
  );
});

test("exporta o deck salvo e apaga depois de confirmar", async ({ page }) => {
  await page.goto("/decks/7");
  await expect(page.getByRole("link", { name: "Exportar .ydk" })).toHaveAttribute(
    "href",
    "/api/decks/7/export.ydk",
  );
  await expect(page.getByRole("link", { name: "Exportar texto" })).toHaveAttribute(
    "href",
    "/api/decks/7/export.txt",
  );

  await page.getByRole("button", { name: "Apagar deck" }).click();
  await page.getByRole("button", { name: "Confirmar: apagar o deck" }).click();
  await expect(page).toHaveURL("/decks");
});

test("põe cartas do baú no deck, até 3 cópias, e mostra o detalhe", async ({ page }) => {
  await page.goto("/decks/7");
  const chest = page.getByRole("region", { name: "Baú" });
  await expect(chest.getByRole("status")).toHaveText("3 cartas");

  await chest.getByRole("button", { name: "Pôr Mago Negro no Main Deck" }).click();
  await expect(page.getByRole("button", { name: "Main Deck (4)" })).toBeVisible();
  const magician = chest.getByRole("listitem").filter({ hasText: "Mago Negro" });
  await expect(magician).toContainText("Tenho 3 · no deck 3");
  // Na terceira cópia, o botão desativa e o baú diz por quê; a linha do deck também.
  await expect(chest.getByRole("button", { name: "Pôr Mago Negro no Main Deck" })).toBeDisabled();
  await expect(magician).toContainText("Já tem 3 no deck.");
  await expect(
    page.getByRole("button", { name: "Pôr mais uma cópia de Mago Negro" }),
  ).toBeDisabled();
  await expect(page.getByText("(já tem 3 no deck)")).toBeVisible();

  await chest
    .getByRole("button", { name: "Pôr Elemental HERO Flame Wingman no Extra Deck" })
    .click();
  await expect(page.getByRole("button", { name: "Extra Deck (2)" })).toBeVisible();

  await chest.getByRole("button", { name: /^Mago Negro/ }).click();
  await expect(page.getByRole("heading", { level: 2, name: "Mago Negro" })).toBeVisible();

  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("a carta nova aparece marcada, dá para ver só as novas, e ela deixa de ser nova ao abrir", async ({
  page,
}) => {
  const seen: unknown[] = [];
  await page.route("**/api/collection/seen", (route) => {
    seen.push(route.request().postDataJSON());
    return route.fulfill({ status: 204 });
  });
  await page.goto("/decks/7");
  const chest = page.getByRole("region", { name: "Baú" });
  await expect(chest.locator(".chest-new")).toContainText("Você tem 1 carta nova.");

  await chest.getByRole("button", { name: "Ver só as novas" }).click();
  await expect(chest.getByRole("status")).toHaveText("1 carta");
  const wingman = chest.getByRole("listitem").filter({ hasText: "Elemental HERO Flame Wingman" });
  await expect(wingman).toContainText("Nova");
  await chest.getByRole("button", { name: /^Elemental HERO Flame Wingman/ }).click();
  await expect(wingman).not.toContainText("Nova");
  // Continua na lista até o filtro ser desligado.
  await expect(chest.getByRole("status")).toHaveText("1 carta");
  expect(seen).toEqual([{ card_ids: [3] }]);

  await chest.getByRole("button", { name: "Ver todas" }).click();
  await chest.getByRole("button", { name: /^Filtros/ }).click();
  await chest.getByLabel("Mais recentes primeiro").check();
  await page
    .getByRole("dialog", { name: "Filtros" })
    .getByRole("button", { name: /^Ver / })
    .click();
  await expect(chest.locator(".chest-item").first()).toContainText("Elemental HERO Flame Wingman");
});

test("o baú mostra também as cartas que o jogador não tem, se pedir", async ({ page }) => {
  await page.goto("/decks/7");
  const chest = page.getByRole("region", { name: "Baú" });
  await chest.getByRole("button", { name: /^Filtros/ }).click();
  await chest.getByLabel("Só as que tenho").uncheck();
  await page
    .getByRole("dialog", { name: "Filtros" })
    .getByRole("button", { name: /^Ver / })
    .click();

  await expect(chest.getByRole("status")).toHaveText("4 cartas");
  await expect(chest.getByRole("listitem").filter({ hasText: "Força Espelho" })).toContainText(
    "Tenho 0 · no deck 0",
  );
});

test("arrasta carta do baú para o Main e uma linha do deck de volta para o baú", async ({
  page,
}) => {
  await page.goto("/decks/7");
  const chest = page.getByRole("region", { name: "Baú" });

  await chest
    .getByRole("listitem")
    .filter({ hasText: "Mago Negro" })
    .dragTo(page.getByRole("button", { name: "Main Deck (3)" }));
  await expect(page.getByRole("button", { name: "Main Deck (4)" })).toBeVisible();

  await page
    .getByRole("list", { name: "Main Deck" })
    .getByRole("listitem")
    .filter({ hasText: "Pote da Ganância" })
    .dragTo(chest);
  await expect(page.getByRole("button", { name: "Main Deck (3)" })).toBeVisible();
});

test("no limite de 50 decks, criar e importar desativam e a página diz por quê", async ({
  page,
}) => {
  await mockDeckApi(page);
  const many = Array.from({ length: 50 }, (_, i) => ({
    id: 100 + i,
    name: `Deck ${i + 1}`,
    updated_at: deck.updated_at,
    counts: { main: 40, extra: 0 },
  }));
  await page.route("**/api/decks", (route) => route.fulfill({ json: { data: many } }));
  await page.goto("/decks");

  await expect(page.getByRole("button", { name: "Criar deck novo" })).toBeDisabled();
  await expect(page.getByText("Você chegou ao limite de 50 decks")).toBeVisible();
  await page.getByLabel("Lista do deck").fill("3 Dark Magician");
  await expect(page.getByRole("button", { name: "Importar" })).toBeDisabled();
});
