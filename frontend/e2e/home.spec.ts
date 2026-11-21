import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession } from "./support.ts";

test.beforeEach(async ({ page }) => mockSession(page));

test("a página inicial mostra o projeto, os atalhos e a fase atual", async ({ page }) => {
  await page.goto("/");
  const main = page.getByRole("main");
  await expect(main.getByRole("heading", { level: 1, name: "GX Project" })).toBeVisible();
  await expect(main.getByText("Fase atual: F5, Duelos contra personagens.")).toBeVisible();
  await expect(main.getByRole("link", { name: "Cartas" })).toHaveAttribute("href", "/cartas");
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
    page.getByRole("navigation", { name: "Principal" }).getByRole("link", { name: "Duelo" }),
  ).toHaveAttribute("href", "/salas");
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

test("o rodapé leva ao código-fonte", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("link", { name: "Código-fonte" })).toHaveAttribute(
    "href",
    "https://github.com/PedroPedrassolli/gx-project",
  );
});
