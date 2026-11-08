import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession } from "./support.ts";

test.beforeEach(async ({ page }) => mockSession(page));

test("cada página tem o próprio título na aba", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveTitle("GX Project");

  await page.goto("/entrar");
  await expect(page).toHaveTitle("Entrar · GX Project");

  await page.goto("/termos");
  await expect(page).toHaveTitle("Termos de uso · GX Project");

  await page.goto("/nada-aqui");
  await expect(page).toHaveTitle("Página não encontrada · GX Project");
});

test("ao navegar, o foco vai para o título da página nova", async ({ page }) => {
  await page.goto("/");
  await page
    .getByRole("navigation", { name: "Principal" })
    .getByRole("link", { name: "Entrar" })
    .click();

  await expect(page.getByRole("heading", { level: 1, name: "Entrar" })).toBeFocused();
  await expect(page).toHaveTitle("Entrar · GX Project");
});

test("o primeiro Tab mostra o link para pular a barra do topo", async ({ page }) => {
  await page.goto("/");
  await page.keyboard.press("Tab");

  const skip = page.getByRole("link", { name: "Pular para o conteúdo" });
  await expect(skip).toBeFocused();
  await expect(skip).toBeInViewport();
  await page.keyboard.press("Enter");
  await expect(page.locator("#conteudo")).toBeFocused();
  await expect(page).toHaveURL("/");

  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});
