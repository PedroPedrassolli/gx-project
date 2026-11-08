import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession, PASSWORD } from "./support.ts";

test("mostra os dados da conta, o link para baixar e passa no axe", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  await page.goto("/");
  await page
    .getByRole("navigation", { name: "Principal" })
    .getByRole("link", { name: "JadenYuki" })
    .click();

  await expect(page.getByRole("heading", { level: 1, name: "Minha conta" })).toBeVisible();
  await expect(page.getByText("jaden@example.com (ainda não confirmado)")).toBeVisible();
  await expect(page.getByText("13 a 17 anos")).toBeVisible();
  await expect(page.getByRole("link", { name: "Baixar meus dados" })).toHaveAttribute(
    "href",
    "/api/me/export",
  );

  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("exclui a conta com a senha, depois de confirmar", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  let password: string | undefined;
  await page.route("**/api/me", (route) => {
    password = route.request().postDataJSON().password;
    return route.fulfill({ status: 204 });
  });
  await page.goto("/conta");
  await page.getByLabel("Senha").fill(PASSWORD);
  await page.getByRole("button", { name: "Excluir minha conta" }).click();
  await page.getByRole("button", { name: "Confirmar: excluir minha conta" }).click();

  await expect(page.getByRole("heading", { level: 1, name: "Conta excluída" })).toBeVisible();
  expect(password).toBe(PASSWORD);
});

test("avisa da senha errada", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  await page.route("**/api/me", (route) =>
    route.fulfill({
      status: 422,
      json: {
        error: { status: 422, message: "Confira a senha.", fields: { password: ["não confere"] } },
      },
    }),
  );
  await page.goto("/conta");
  await page.getByLabel("Senha").fill("errada123");
  await page.getByRole("button", { name: "Excluir minha conta" }).click();
  await page.getByRole("button", { name: "Confirmar: excluir minha conta" }).click();

  await expect(page.getByLabel("Senha")).toHaveAccessibleDescription(/Não confere\./);
});
