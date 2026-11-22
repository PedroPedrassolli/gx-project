import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession } from "./support.ts";

test.beforeEach(async ({ page }) => mockSession(page));

test("a página inicial mostra o projeto, os atalhos e a fase atual", async ({ page }) => {
  await page.goto("/");
  const main = page.getByRole("main");
  await expect(main.getByRole("heading", { level: 1, name: "GX Project" })).toBeVisible();
  await expect(main.getByText("Fase atual: F6, Front novo.")).toBeVisible();
  await expect(main.getByRole("link", { name: "Personagens" })).toHaveAttribute(
    "href",
    "/personagens",
  );
  // O duelo leva às salas (lá, quem não entrou vê o convite para entrar).
  await expect(main.getByRole("link", { name: "Duelo" })).toHaveAttribute("href", "/salas");
  // As seis cartas aparecem para todos (sem conta, as que pedem login mandam entrar);
  // entrar e criar conta ficam no topo.
  await expect(main.getByRole("list", { name: "Atalhos" }).getByRole("listitem")).toHaveCount(6);
  await expect(main.getByRole("link", { name: "Loja" })).toHaveAttribute("href", "/loja");
  await expect(main.getByRole("link", { name: "Desafios" })).toHaveAttribute("href", "/desafios");
  await expect(main.getByRole("link", { name: "Decks" })).toHaveAttribute("href", "/decks");
  await expect(
    page.getByRole("navigation", { name: "Principal" }).getByRole("link", { name: "Criar conta" }),
  ).toHaveAttribute("href", "/cadastro");
  // Sem cartas na tela, nada de conexão com o site das imagens.
  await expect(page.locator('link[rel="preconnect"]')).toHaveCount(0);
});

test("com a conta aberta, a mesa tem os decks e a coleção", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  await page.goto("/");
  const main = page.getByRole("main");
  await expect(main.getByRole("link", { name: "Decks" })).toHaveAttribute("href", "/decks");
  await expect(main.getByRole("link", { name: "Coleção" })).toHaveAttribute("href", "/colecao");
  await expect(page.getByRole("link", { name: "Criar conta" })).toHaveCount(0);
  await expect(
    page.getByRole("navigation", { name: "Principal" }).getByRole("link", { name: "Jogar" }),
  ).toHaveAttribute("href", "/jogar");
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

test("a página inicial passa no axe sem violações, com e sem conta", async ({ page }) => {
  await page.goto("/");
  await expect(
    page.getByRole("navigation", { name: "Principal" }).getByRole("link", { name: "Entrar" }),
  ).toBeVisible();
  let results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);

  await mockSession(page, { loggedIn: true });
  await page.reload();
  await expect(page.getByRole("main").getByRole("link", { name: "Coleção" })).toBeVisible();
  results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
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
