import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession, PASSWORD, PLAYER } from "./support.ts";

const topbar = (page: import("@playwright/test").Page) =>
  page.getByRole("navigation", { name: "Principal" });

test("entra com e-mail e senha e vê o apelido na barra do topo", async ({ page }) => {
  await mockSession(page);
  await page.goto("/entrar");
  await page.getByLabel("E-mail").fill(PLAYER.email);
  await page.getByLabel("Senha").fill(PASSWORD);
  await page.getByRole("button", { name: "Entrar" }).click();

  await expect(page).toHaveURL("/");
  await expect(topbar(page).getByText("Olá, JadenYuki")).toBeVisible();
});

test("mostra o erro do login e fica na página", async ({ page }) => {
  await mockSession(page);
  await page.goto("/entrar");
  await page.getByLabel("E-mail").fill(PLAYER.email);
  await page.getByLabel("Senha").fill("errada123");
  await page.getByRole("button", { name: "Entrar" }).click();

  await expect(page.getByRole("alert")).toHaveText("E-mail ou senha incorretos.");
  await expect(page).toHaveURL("/entrar");
});

test("sai pela barra do topo", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  await page.goto("/");
  await topbar(page).getByRole("button", { name: "Sair" }).click();

  await expect(topbar(page).getByRole("link", { name: "Entrar" })).toBeVisible();
});

test("página que não existe avisa e leva de volta", async ({ page }) => {
  await mockSession(page);
  await page.goto("/nada-aqui");

  await expect(
    page.getByRole("heading", { level: 1, name: "Página não encontrada" }),
  ).toBeVisible();
  await expect(page.getByRole("link", { name: "Voltar para o começo" })).toHaveAttribute(
    "href",
    "/",
  );
});

test("a página de entrar passa no axe, também com erro na tela", async ({ page }) => {
  await mockSession(page);
  await page.goto("/entrar");
  await page.getByRole("button", { name: "Entrar" }).click();
  await expect(page.getByRole("alert")).toBeVisible();

  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});
