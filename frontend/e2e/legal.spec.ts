import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession } from "./support.ts";

const footer = (page: Page) => page.getByRole("contentinfo");

test.beforeEach(async ({ page }) => mockSession(page));

test("o rodapé de todas as páginas leva aos termos e à privacidade", async ({ page }) => {
  await page.goto("/");
  await footer(page).getByRole("link", { name: "Termos de uso" }).click();
  await expect(page).toHaveURL("/termos");
  await expect(page.getByRole("heading", { level: 1, name: "Termos de uso" })).toBeVisible();
  await expect(page.getByText("Versão de 08/11/2026.")).toBeVisible();

  await footer(page).getByRole("link", { name: "Privacidade" }).click();
  await expect(page).toHaveURL("/privacidade");
  await expect(
    page.getByRole("heading", { level: 1, name: "Política de privacidade" }),
  ).toBeVisible();
});

test("o rodapé tem o aviso de fã e os créditos", async ({ page }) => {
  await page.goto("/entrar");
  await expect(footer(page)).toContainText("Yu-Gi-Oh! é marca registrada da Konami");
  await expect(footer(page).getByRole("link", { name: "Yugipedia" })).toBeVisible();
  await expect(footer(page).getByRole("link", { name: "Código-fonte" })).toHaveAttribute(
    "href",
    "https://github.com/PedroPedrassolli/gx-project",
  );
});

test("a política diz quem cuida dos dados e como falar com ele", async ({ page }) => {
  await page.goto("/privacidade");
  await expect(page.getByText("Pedro Pedrassolli, mantenedor do GX Project")).toBeVisible();
  await expect(
    page.getByRole("main").getByRole("link", { name: "pedropedrassolli@outlook.com" }).first(),
  ).toHaveAttribute("href", "mailto:pedropedrassolli@outlook.com");
  await expect(page.getByRole("row", { name: /Coleção e decks/ })).toBeVisible();
  await expect(page.getByRole("link", { name: "Minha conta" })).toHaveAttribute("href", "/conta");
});

for (const path of ["/termos", "/privacidade"]) {
  test(`${path} passa no axe sem violações`, async ({ page }) => {
    await page.goto(path);
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
    expect(results.violations).toEqual([]);
  });
}
