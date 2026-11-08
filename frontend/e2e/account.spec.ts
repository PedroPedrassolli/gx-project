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

test.describe("cadastro", () => {
  test.beforeEach(async ({ page }) => {
    await mockSession(page);
    await page.route("**/api/registrations", (route) => {
      const form = route.request().postDataJSON();
      if (form.nickname === "Mestre_Porra") {
        return route.fulfill({
          status: 422,
          json: {
            error: {
              status: 422,
              message: "Confira os campos.",
              fields: {
                nickname: ["não é permitido"],
                birth_date: ["precisa ser de quem tem 13 anos ou mais"],
              },
            },
          },
        });
      }
      return route.fulfill({ status: 201, json: { user: PLAYER } });
    });
    await page.goto("/cadastro");
  });

  async function fill(page: import("@playwright/test").Page, nickname: string) {
    await page.getByLabel("E-mail").fill(PLAYER.email);
    await page.getByLabel("Senha").fill(PASSWORD);
    await page.getByLabel("Apelido").fill(nickname);
    await page.getByLabel("Data de nascimento").fill("2010-05-01");
    await page.getByRole("button", { name: "Criar conta" }).click();
  }

  test("cria a conta e pede para confirmar o e-mail", async ({ page }) => {
    await fill(page, "JadenYuki");

    await expect(page.getByRole("heading", { level: 1, name: "Conta criada!" })).toBeVisible();
    await expect(page.getByRole("status")).toContainText(PLAYER.email);
  });

  test("mostra o erro de cada campo ao lado dele, e passa no axe", async ({ page }) => {
    await fill(page, "Mestre_Porra");

    await expect(page.getByLabel("Apelido")).toHaveAttribute("aria-invalid", "true");
    await expect(page.getByLabel("Apelido")).toHaveAccessibleDescription(/Não é permitido\./);
    await expect(page.getByLabel("Data de nascimento")).toHaveAccessibleDescription(
      /Precisa ser de quem tem 13 anos ou mais\./,
    );
    await expect(page.getByLabel("E-mail")).not.toHaveAttribute("aria-invalid", "true");

    const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
    expect(results.violations).toEqual([]);
  });
});
