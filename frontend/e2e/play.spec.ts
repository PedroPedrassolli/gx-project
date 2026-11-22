import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession } from "./support.ts";

const CHARACTERS = [
  { id: "chumley", name: "Chumley", position: 1, status: "beaten", wins: 1 },
  {
    id: "syrus",
    name: "Syrus",
    position: 2,
    status: "unlocked",
    wins: 0,
    signature: { id: 9, name: "Steamroid", image: 44729197 },
  },
].map((character) => ({
  ...character,
  description: `O deck de ${character.name}.`,
  group: { id: "alunos", name: "Alunos da Academia" },
  deck: `Deck de ${character.name}`,
  bonus: 120,
}));
const room = (code: string, owner: string) => ({
  code,
  owner,
  players: 1,
  seats: 2,
  banlist: true,
  destiny_draw: false,
  decision_seconds: 90,
  duel_minutes: null,
});

test("Jogar mostra o próximo personagem e as salas abertas para entrar direto", async ({
  page,
}) => {
  await mockSession(page, { loggedIn: true });
  await page.route("**/api/characters", (route) =>
    route.fulfill({ json: { data: { characters: CHARACTERS } } }),
  );
  const rooms = ["ABC234", "DEF567", "GHJ892", "KLM345"].map((code, index) =>
    room(code, ["Syrus", "Alexis", "Bastion", "Chazz"][index] ?? "Jaden"),
  );
  await page.route("**/api/rooms", (route) => route.fulfill({ json: { data: rooms } }));
  await page.goto("/jogar");

  const main = page.getByRole("main");
  await expect(main.getByRole("heading", { name: "Próximo desafiante: Syrus" })).toBeVisible();
  await expect(main.getByRole("link", { name: "Duelar contra Syrus" })).toHaveAttribute(
    "href",
    "/personagens?duelar=syrus",
  );
  // As três primeiras salas e o caminho para o resto.
  const open = main.getByRole("region", { name: "Salas abertas" });
  await expect(open.getByRole("listitem").filter({ hasText: "Sala de" })).toHaveCount(3);
  await expect(open.getByRole("link", { name: "Sala de Syrus" })).toHaveAttribute(
    "href",
    "/salas/ABC234",
  );
  await expect(open.getByRole("listitem").first()).toContainText("1 de 2");
  await expect(open.getByRole("link", { name: "Ver as 4 salas" })).toHaveAttribute(
    "href",
    "/salas",
  );
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("sem sala aberta, Jogar manda criar uma", async ({ page }) => {
  await mockSession(page, { loggedIn: true });
  await page.route("**/api/characters", (route) =>
    route.fulfill({ json: { data: { characters: CHARACTERS } } }),
  );
  await page.route("**/api/rooms", (route) => route.fulfill({ json: { data: [] } }));
  await page.goto("/jogar");

  await expect(page.getByText("Nenhuma sala aberta agora.")).toBeVisible();
  await expect(
    page.getByRole("main").getByRole("link", { name: "Crie uma", exact: true }),
  ).toHaveAttribute("href", "/salas");
});
