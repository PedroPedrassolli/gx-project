import { expect, test, type Page } from "@playwright/test";

// O computador pode abrir uma corrente na hora que quiser (um Tufão Espacial Místico no começo
// do nosso turno, por exemplo) e a pergunta tampa a mesa. Repete o passo recusando cada pergunta
// que aparecer, aberta ou minimizada, até ele dar certo.
async function whileDeclining(page: Page, step: () => Promise<unknown>) {
  const reopen = page.getByRole("button", { name: /^Responder:/ });
  const decline = page.getByRole("button", { name: /^(Não encadear|Não)$/ }).first();
  await expect(async () => {
    // "Responder" fica na faixa das fases, atrás da pergunta aberta: só serve se ela foi minimizada.
    if (await decline.isVisible()) await decline.click({ timeout: 2_000 });
    else if (await reopen.isVisible()) await reopen.click({ timeout: 2_000 });
    await step();
  }).toPass({ timeout: 30_000 });
}

async function surrender(page: Page) {
  await whileDeclining(page, () =>
    page.getByRole("button", { name: "Desistir" }).click({ timeout: 2_000 }),
  );
  await page
    .getByRole("dialog", { name: "Desistir do duelo?" })
    .getByRole("button", { name: "Desistir" })
    .click();
}

// Contra o computador, no Rails de verdade: começar o duelo contra o Chumley, encerrar o turno
// (o computador joga o dele na mesma resposta), desistir e voltar pelo resultado.
test("duelo contra personagem: o computador joga o turno dele e o resultado leva de volta", async ({
  page,
}) => {
  await page.goto("/entrar");
  await page.getByLabel("E-mail").fill("bastion@example.com");
  await page.getByLabel("Senha").fill("duelista123");
  await page.getByRole("main").getByRole("button", { name: "Entrar" }).click();
  await expect(page.getByRole("navigation", { name: "Principal" })).toContainText("Jogar");

  await page.goto("/personagens");
  await expect(page.locator("ol.characters > li").first()).toContainText("Chumley");
  // Duelo que sobrou de uma rodada anterior do teste (o e2e:preparar não apaga partidas).
  const leftover = page.getByRole("link", { name: "Voltar para a mesa" }).first();
  if (await leftover.isVisible()) {
    await leftover.click();
    await surrender(page);
    await page.goto("/personagens");
  }
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

  await whileDeclining(page, () =>
    page.getByRole("button", { name: "Encerrar o turno" }).click({ timeout: 2_000 }),
  );
  await whileDeclining(page, () =>
    expect(page.getByText(`Turno ${before + 2}, vez de Bastion`)).toBeVisible({ timeout: 2_000 }),
  );

  await surrender(page);
  const result = page.getByRole("dialog", { name: "Chumley venceu." });
  await expect(result).toBeVisible();
  // Desistir contra o computador paga como duelo curto.
  await expect(result.getByRole("table", { name: "DP do duelo" })).toContainText("+10 DP");
  await result.getByRole("link", { name: "Duelar de novo" }).click();
  await expect(page.getByRole("dialog", { name: "Duelar contra Chumley" })).toBeVisible();
});
