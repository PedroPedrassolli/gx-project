import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession } from "./support.ts";

test.beforeEach(async ({ page }) => mockSession(page));

test("a página inicial mostra o projeto, os atalhos e a fase atual", async ({ page }) => {
  await page.goto("/");
  const main = page.getByRole("main");
  await expect(main.getByRole("heading", { level: 1, name: "GX Project" })).toBeVisible();
  await expect(main.getByText("Fase atual: F3, Duelo 1x1 em sala.")).toBeVisible();
  await expect(main.getByRole("link", { name: "Cartas" })).toHaveAttribute("href", "/cartas");
  await expect(main.getByRole("link", { name: "Criar conta" })).toHaveAttribute(
    "href",
    "/cadastro",
  );
  // Decks e Coleção só aparecem para quem entrou.
  await expect(main.getByRole("link", { name: "Decks" })).toHaveCount(0);
});

test("com a conta aberta, a mesa tem os decks e a coleção", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  await page.goto("/");
  const main = page.getByRole("main");
  await expect(main.getByRole("link", { name: "Decks" })).toHaveAttribute("href", "/decks");
  await expect(main.getByRole("link", { name: "Coleção" })).toHaveAttribute("href", "/colecao");
  await expect(main.getByRole("link", { name: "Criar conta" })).toHaveCount(0);
});

test("a página inicial passa no axe sem violações, com e sem conta", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("main").getByRole("link", { name: "Entrar" })).toBeVisible();
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
