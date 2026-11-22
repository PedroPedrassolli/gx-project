import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession } from "./support.ts";

test.beforeEach(async ({ page }) => mockSession(page));

// A API do início de quem tem conta: os personagens, a coleção, os desafios e a loja.
async function mockHomeApi(page: Page) {
  const data: Record<string, unknown> = {
    "/api/characters": {
      characters: [
        {
          id: "chumley",
          position: 1,
          name: "Chumley",
          description: "Coalas.",
          group: { id: "alunos", name: "Alunos" },
          deck: "",
          bonus: 60,
          wins: 1,
          status: "beaten",
        },
        {
          id: "syrus",
          position: 2,
          name: "Syrus",
          description: "Veículos que se fundem em máquinas maiores.",
          group: { id: "alunos", name: "Alunos" },
          deck: "",
          bonus: 120,
          signature: {
            id: 9,
            name: "Super Vehicroid Jumbo Drill",
            name_pt: "Super Veicroide Perfuratriz Gigante",
            image: 36256625,
          },
          wins: 0,
          status: "unlocked",
        },
      ],
    },
    "/api/challenges": { done: 12, total: 102, challenges: [] },
    "/api/shop": {
      balance: 1234,
      level: 2,
      packs: [
        {
          id: 1,
          name: "Beginner Monsters",
          price: 50,
          cards_per_pack: 5,
          available: true,
          hint: null,
          new: true,
        },
      ],
    },
  };
  await page.route("**/api/**", (route) => {
    const path = new URL(route.request().url()).pathname;
    if (path === "/api/session") return route.fallback();
    if (path === "/api/collection") {
      return route.fulfill({
        json: { data: [], meta: { total: { owned: 54, cards: 3484, percent: 1.5 }, packs: [] } },
      });
    }
    if (path in data) return route.fulfill({ json: { data: data[path] } });
    return route.fulfill({ status: 503, json: { error: { status: 503, message: "Desligado." } } });
  });
}

test("sem conta, o início convida a criar conta, mostra o jogo e a fase atual", async ({
  page,
}) => {
  await page.goto("/");
  const main = page.getByRole("main");
  await expect(main.getByRole("heading", { level: 1, name: "GX Project" })).toBeVisible();
  await expect(main.getByText("Fase atual: F6, Front novo.")).toBeVisible();
  await expect(main.getByRole("link", { name: "Criar conta" })).toHaveAttribute(
    "href",
    "/cadastro",
  );
  await expect(main.getByRole("link", { name: "Entrar" })).toHaveAttribute("href", "/entrar");
  await expect(main.getByRole("link", { name: "Ver as cartas" })).toHaveAttribute(
    "href",
    "/cartas",
  );
  await expect(
    main.getByRole("heading", { level: 2, name: "Contra os personagens" }),
  ).toBeVisible();
  await expect(
    page.getByRole("navigation", { name: "Principal" }).getByRole("link", { name: "Criar conta" }),
  ).toHaveAttribute("href", "/cadastro");
});

test("com conta, o início mostra o próximo personagem, o progresso e a loja", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  await mockHomeApi(page);
  await page.goto("/");
  const main = page.getByRole("main");
  await expect(main.getByRole("heading", { level: 1, name: "Olá, JadenYuki" })).toBeVisible();
  await expect(
    main.getByRole("heading", { level: 2, name: "Próximo desafiante: Syrus" }),
  ).toBeVisible();
  await expect(
    main.getByText("A primeira vitória dá a carta Super Veicroide Perfuratriz Gigante."),
  ).toBeVisible();
  await expect(main.getByRole("link", { name: "Duelar contra Syrus" })).toHaveAttribute(
    "href",
    "/personagens?duelar=syrus",
  );
  await expect(main.getByRole("link", { name: /Coleção\s*54\s*de 3\.484 cartas/ })).toHaveAttribute(
    "href",
    "/colecao",
  );
  await expect(
    main.getByRole("link", { name: /Desafios\s*12\s*de 102 concluídos/ }),
  ).toHaveAttribute("href", "/desafios");
  await expect(main.getByRole("link", { name: /1 pacote novo na loja/ })).toHaveAttribute(
    "href",
    "/loja",
  );
  await expect(page.getByRole("link", { name: "Criar conta" })).toHaveCount(0);
  await expect(
    page.getByRole("navigation", { name: "Principal" }).getByRole("link", { name: "Jogar" }),
  ).toHaveAttribute("href", "/jogar");
});

test("com um duelo aberto, o início leva de volta à mesa (sem repetir o aviso do topo)", async ({
  page,
}) => {
  await mockSession(page, { loggedIn: true, duel: { match_id: 5, room_code: null } });
  await mockHomeApi(page);
  await page.goto("/");
  const main = page.getByRole("main");
  await expect(
    main.getByRole("heading", { level: 2, name: "Você tem um duelo em andamento" }),
  ).toBeVisible();
  await expect(main.getByRole("link", { name: "Voltar para a mesa" })).toHaveAttribute(
    "href",
    "/duelo/5",
  );
  await expect(page.getByRole("link", { name: "Voltar para a mesa" })).toHaveCount(1);
});

test("o início passa no axe sem violações, com e sem conta", async ({ page }) => {
  await page.goto("/");
  await expect(
    page.getByRole("navigation", { name: "Principal" }).getByRole("link", { name: "Entrar" }),
  ).toBeVisible();
  let results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);

  await mockSession(page, { loggedIn: true });
  await mockHomeApi(page);
  await page.reload();
  await expect(page.getByRole("link", { name: "Duelar contra Syrus" })).toBeVisible();
  results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("no celular, o menu é a barra de abas embaixo, com a aba atual marcada", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  const menu = page.getByRole("navigation", { name: "Principal" });
  const box = await menu.boundingBox();
  expect(Math.round((box?.y ?? 0) + (box?.height ?? 0))).toBe(844);
  await expect(menu.getByRole("link", { name: "Início" })).toHaveAttribute("aria-current", "page");

  await menu.getByRole("link", { name: "Jogar" }).click();
  await expect(page.getByRole("heading", { level: 1, name: "Jogar" })).toBeVisible();
  await expect(menu.getByRole("link", { name: "Jogar" })).toHaveAttribute("aria-current", "page");
  await expect(
    page.getByRole("main").getByRole("link", { name: /Contra os personagens/ }),
  ).toHaveAttribute("href", "/personagens");
  await expect(page.getByRole("main").getByRole("link", { name: /Com os amigos/ })).toHaveAttribute(
    "href",
    "/salas",
  );
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("o menu marca a página atual", async ({ page }) => {
  await page.goto("/cartas");
  await expect(
    page.getByRole("navigation", { name: "Principal" }).getByRole("link", { name: "Cartas" }),
  ).toHaveAttribute("aria-current", "page");
});

test("o rodapé não fala do código-fonte; só a página de termos, pela AGPL", async ({ page }) => {
  await page.goto("/");
  await expect(
    page.getByRole("contentinfo").getByRole("link", { name: /código-fonte/i }),
  ).toHaveCount(0);
  await page.goto("/termos");
  await expect(page.getByRole("main").getByRole("link", { name: "código-fonte" })).toHaveAttribute(
    "href",
    "https://github.com/PedroPedrassolli/gx-project",
  );
});
