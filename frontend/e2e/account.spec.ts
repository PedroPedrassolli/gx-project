import { expect, test } from "@playwright/test";
import { mockSession } from "./support.ts";

const topbar = (page: import("@playwright/test").Page) =>
  page.getByRole("navigation", { name: "Principal" });

test("mostra quem está logado e sai pela barra do topo", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  await page.goto("/");
  await expect(topbar(page).getByText("Olá, JadenYuki")).toBeVisible();

  await topbar(page).getByRole("button", { name: "Sair" }).click();

  await expect(topbar(page).getByText("Olá, JadenYuki")).toBeHidden();
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
