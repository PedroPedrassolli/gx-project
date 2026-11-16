import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession } from "./support.ts";

const challenges = [
  {
    number: 1,
    label: "Causar 10.000 ou mais de dano de batalha num duelo",
    done: true,
    possible: true,
  },
  { number: 25, label: "Vencer uma partida melhor de três", done: false, possible: false },
  { number: 26, label: "Empatar um duelo", done: false, possible: true },
];

test("sem login, pede para entrar", async ({ page }) => {
  await mockSession(page);
  await page.goto("/desafios");

  await expect(page.getByRole("link", { name: "Entre na sua conta" })).toBeVisible();
});

test("a lista mostra o progresso, os concluídos e os que ainda não dá para concluir", async ({
  page,
}) => {
  await mockSession(page, { loggedIn: true });
  await page.route("**/api/challenges", (route) =>
    route.fulfill({ json: { data: { done: 1, total: 104, challenges } } }),
  );
  await page.goto("/desafios");

  await expect(
    page.getByRole("heading", { name: "Você concluiu 1 de 104 desafios" }),
  ).toBeVisible();
  const items = page.locator("ol.challenges").getByRole("listitem");
  await expect(items).toHaveText([
    "Causar 10.000 ou mais de dano de batalha num dueloConcluído",
    "Vencer uma partida melhor de trêsEm breve",
    "Empatar um duelo",
  ]);
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);

  await page.getByLabel("Só os que faltam").check();
  await expect(items).toHaveCount(2);
});

test("a conta leva para os desafios", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  await page.route("**/api/challenges", (route) =>
    route.fulfill({ json: { data: { done: 0, total: 104, challenges: [] } } }),
  );
  await page.goto("/conta");
  await page.getByRole("link", { name: "Ver os meus desafios" }).click();

  await expect(page).toHaveURL("/desafios");
});
