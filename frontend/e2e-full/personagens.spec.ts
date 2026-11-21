import { expect, test } from "@playwright/test";

// Contra o computador, no Rails de verdade: começar o duelo contra o Chumley, encerrar o turno
// (o computador joga o dele na mesma resposta), desistir e voltar pelo resultado.
test("duelo contra personagem: o computador joga o turno dele e o resultado leva de volta", async ({
  page,
}) => {
  await page.goto("/entrar");
  await page.getByLabel("E-mail").fill("bastion@example.com");
  await page.getByLabel("Senha").fill("duelista123");
  await page.getByRole("main").getByRole("button", { name: "Entrar" }).click();
  await expect(page.getByRole("navigation", { name: "Principal" })).toContainText("Duelo");

  await page.goto("/personagens");
  await expect(page.locator("ol.characters > li").first()).toContainText("Chumley");
  await page.getByRole("button", { name: "Duelar contra Chumley" }).click();
  await page
    .getByRole("dialog", { name: "Duelar contra Chumley" })
    .getByRole("button", { name: "Começar o duelo" })
    .click();
  await expect(page).toHaveURL(/\/duelo\/\d+$/, { timeout: 15_000 });

  // Quem começa é sorteado; se foi o computador, o turno dele já veio jogado.
  const turn = page.getByText(/^Turno \d+, vez de Bastion$/);
  await expect(turn).toBeVisible({ timeout: 15_000 });
  const before = Number((await turn.textContent())?.match(/\d+/)?.[0]);
  await expect(page.getByRole("button", { name: "Frases" })).toHaveCount(0);

  await page.getByRole("button", { name: "Encerrar o turno" }).click();
  await expect(page.getByText(`Turno ${before + 2}, vez de Bastion`)).toBeVisible({
    timeout: 15_000,
  });

  await page.getByRole("button", { name: "Desistir" }).click();
  await page
    .getByRole("dialog", { name: "Desistir do duelo?" })
    .getByRole("button", { name: "Desistir" })
    .click();
  const result = page.getByRole("dialog", { name: "Chumley venceu." });
  await expect(result).toBeVisible();
  // Desistir contra o computador paga como duelo curto.
  await expect(result.getByRole("table", { name: "DP do duelo" })).toContainText("+10 DP");
  await result.getByRole("link", { name: "Duelar de novo" }).click();
  await expect(page.getByRole("dialog", { name: "Duelar contra Chumley" })).toBeVisible();
});
