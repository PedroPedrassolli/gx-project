import { expect, test, type Browser, type Page } from "@playwright/test";

// Dois navegadores, cada um com a sua conta, no Rails de verdade: a sala, o pronto, o duelo
// com a engine, a desistência, o resultado para os dois e o replay.
async function player(browser: Browser, email: string) {
  const page = await (await browser.newContext()).newPage();
  await page.goto("/entrar");
  await page.getByLabel("E-mail").fill(email);
  await page.getByLabel("Senha").fill("duelista123");
  await page.getByRole("main").getByRole("button", { name: "Entrar" }).click();
  await expect(page.getByRole("navigation", { name: "Principal" })).toContainText("Duelo");
  return page;
}

async function ready(page: Page) {
  await page.getByLabel("Deck", { exact: true }).selectOption({ index: 1 });
  await page.getByRole("button", { name: "Estou pronto" }).click();
}

test("duelo 1x1: sala com código, os dois prontos, jogadas, desistência, resultado e replay", async ({
  browser,
}) => {
  const jaden = await player(browser, "jaden@example.com");
  const syrus = await player(browser, "syrus@example.com");

  await jaden.getByRole("link", { name: "Duelo" }).first().click();
  await jaden.getByRole("button", { name: "Criar sala" }).click();
  const title = jaden.getByRole("heading", { level: 1 });
  await expect(title).toHaveText(/^Sala [A-Z2-9]{6}$/);
  const code = (await title.textContent())?.slice(-6) ?? "";

  await syrus.goto("/salas");
  await syrus.getByLabel("Código da sala").fill(code);
  await syrus.getByRole("button", { name: "Ir para a sala" }).click();
  await syrus.getByRole("button", { name: "Entrar na sala" }).click();
  await expect(syrus.getByRole("list", { name: "Lugares" })).toContainText("Jaden");

  await ready(jaden);
  await ready(syrus);
  // Quem começa sai no pedra, papel e tesoura: a pedra do Jaden quebra a tesoura do Syrus, e o
  // Jaden escolhe começar.
  await jaden
    .getByRole("group", { name: "Sua mão" })
    .getByRole("button", { name: "Pedra" })
    .click();
  await syrus
    .getByRole("group", { name: "Sua mão" })
    .getByRole("button", { name: "Tesoura" })
    .click();
  await jaden.getByRole("button", { name: "Começar", exact: true }).click();
  for (const page of [jaden, syrus])
    await expect(page).toHaveURL(/\/duelo\/\d+$/, { timeout: 15_000 });

  // O Jaden baixa uma carta e encerra o turno, e o Syrus desiste no turno dele.
  const status = (page: Page) => page.getByRole("status").filter({ hasText: /Sua vez|Vez de/ });
  await expect(status(jaden)).toHaveText("Sua vez.");
  const [first, second] = [jaden, syrus];
  const firstName = "Jaden";

  // Carta baixada (quando a mão tem uma): o outro vê só o verso, porque o servidor não manda o
  // que ela é. Baixar não abre efeito nem corrente, então a vez segue igual.
  const set = first.getByRole("button", { name: /^Baixar .+ \(mão\)/ }).first();
  if ((await set.count()) > 0) {
    await set.click();
    const field = second
      .getByRole("list", { name: `Monstros de ${firstName}` })
      .or(second.getByRole("list", { name: `Magias e armadilhas de ${firstName}` }))
      .or(second.getByRole("group", { name: `Campo de ${firstName}` }));
    await expect(field.getByRole("img", { name: "Carta virada para baixo" })).toHaveCount(1, {
      timeout: 15_000,
    });
  }
  await first.getByRole("button", { name: "Encerrar o turno" }).click();
  await expect(second.getByText(/^Turno 2, vez de/)).toBeVisible({ timeout: 15_000 });

  await second.getByRole("button", { name: "Desistir" }).click();
  await second
    .getByRole("dialog", { name: "Desistir do duelo?" })
    .getByRole("button", { name: "Desistir" })
    .click();
  await expect(second.getByRole("heading", { name: /venceu\./ })).toBeVisible();
  await expect(first.getByRole("heading", { name: "Você venceu!" })).toBeVisible({
    timeout: 15_000,
  });
  await expect(first.getByText(/desistiu\./)).toBeVisible();

  await first.getByRole("link", { name: "Ver o replay" }).click();
  await expect(first.getByText(/Turno 1 de 2/)).toBeVisible();
  await first.getByLabel("Ir para o turno").selectOption("2");
  await expect(first.getByText(/Turno 2 de 2/)).toBeVisible();

  // A sala voltou a esperar: a revanche é ficar pronto de novo.
  await second.getByRole("link", { name: "Voltar para a sala" }).click();
  await expect(second.getByRole("button", { name: "Estou pronto" })).toBeVisible();
});
