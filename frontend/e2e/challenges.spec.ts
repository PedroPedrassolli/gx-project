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

const missions = [
  {
    id: "torneio_slifer_red",
    name: "Torneio Slifer Red",
    goal: "Vença 10 duelos",
    reward: "Libera os pacotes Test of Luck e Power of the Heroes",
    progress: 4,
    target: 10,
    done: false,
    repeats: false,
  },
  {
    id: "carta_da_semana",
    name: "Carta da semana",
    goal: "Vença 5 duelos na mesma semana",
    reward: "Dá a carta da vez",
    progress: 5,
    target: 5,
    done: true,
    repeats: true,
  },
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
  await page.route("**/api/missions", (route) => route.fulfill({ json: { data: missions } }));
  await page.route("**/api/challenges", (route) =>
    route.fulfill({ json: { data: { done: 1, total: 104, challenges } } }),
  );
  await page.goto("/desafios");

  await expect(
    page.getByRole("heading", { name: "Você concluiu 1 de 104 desafios" }),
  ).toBeVisible();
  const cards = page.locator("ul.missions").getByRole("listitem");
  await expect(cards.nth(0)).toContainText("Torneio Slifer Red");
  await expect(cards.nth(0)).toContainText("Vença 10 duelos. Libera os pacotes");
  await expect(cards.nth(0)).toContainText("4 de 10");
  await expect(cards.nth(1)).toContainText("Concluída nesta semana");
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
  await page.getByRole("link", { name: "Ver as missões e os desafios" }).click();

  await expect(page).toHaveURL("/desafios");
});
