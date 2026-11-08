import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession, PLAYER } from "./support.ts";

const STALE_LINK = {
  error: { status: 422, message: "Link vencido ou inválido. Peça outro e-mail." },
};

test.beforeEach(async ({ page }) => mockSession(page));

test("esqueci a senha: pede o link pelo e-mail, saindo do entrar", async ({ page }) => {
  await page.route("**/api/password", (route) => route.fulfill({ status: 202 }));
  await page.goto("/entrar");
  await page.getByRole("link", { name: "Esqueci a senha" }).click();
  await page.getByLabel("E-mail").fill(PLAYER.email);
  await page.getByRole("button", { name: "Mandar o link" }).click();

  await expect(page.getByRole("status")).toContainText(
    "mandamos um link para criar uma senha nova",
  );
});

test("senha nova: troca com o token do link", async ({ page }) => {
  let sent: unknown;
  await page.route("**/api/password", (route) => {
    sent = route.request().postDataJSON();
    return route.fulfill({ json: { user: PLAYER } });
  });
  await page.goto("/nova-senha?token=abc123");
  await page.getByLabel("Senha nova").fill("novasenha123");
  await page.getByRole("button", { name: "Trocar a senha" }).click();

  await expect(page.getByRole("heading", { level: 1, name: "Senha trocada!" })).toBeVisible();
  expect(sent).toEqual({ token: "abc123", password: "novasenha123" });
});

test("senha nova: link vencido oferece pedir outro, e a tela passa no axe", async ({ page }) => {
  await page.route("**/api/password", (route) => route.fulfill({ status: 422, json: STALE_LINK }));
  await page.goto("/nova-senha?token=velho");
  await page.getByLabel("Senha nova").fill("novasenha123");
  await page.getByRole("button", { name: "Trocar a senha" }).click();

  await expect(page.getByRole("alert")).toContainText("Link vencido ou inválido.");
  await expect(page.getByRole("link", { name: "Pedir outro link" })).toHaveAttribute(
    "href",
    "/esqueci-a-senha",
  );
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("confirmar e-mail: confirma assim que abre o link", async ({ page }) => {
  await page.route("**/api/email_verification", (route) =>
    route.fulfill({ json: { user: { ...PLAYER, email_verified: true } } }),
  );
  await page.goto("/verificar-email?token=abc123");

  await expect(page.getByRole("status")).toHaveText("E-mail confirmado. Obrigado!");
});

test("confirmar e-mail: avisa do link vencido", async ({ page }) => {
  await page.route("**/api/email_verification", (route) =>
    route.fulfill({ status: 422, json: STALE_LINK }),
  );
  await page.goto("/verificar-email?token=velho");

  await expect(page.getByRole("alert")).toHaveText("Link vencido ou inválido. Peça outro e-mail.");
});
