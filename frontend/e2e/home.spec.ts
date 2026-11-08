import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("a página inicial mostra o projeto e a fase atual", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1, name: "GX Project" })).toBeVisible();
  await expect(page.getByText("Fase atual: F1, Catálogo de cartas.")).toBeVisible();
});

test("a página inicial passa no axe sem violações", async ({ page }) => {
  await page.goto("/");
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("o rodapé leva ao código-fonte", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("link", { name: "Código-fonte" })).toHaveAttribute(
    "href",
    "https://github.com/PedroPedrassolli/gx-project",
  );
});
