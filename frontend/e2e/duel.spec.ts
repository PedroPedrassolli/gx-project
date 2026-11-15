import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession } from "./support.ts";

const CARDS = [
  {
    id: 1,
    code: 46986414,
    name: "Dark Magician",
    name_pt: "Mago Negro",
    card_type: "Monster",
    image: 46986414,
  },
  { id: 2, code: 89631139, name: "Blue-Eyes White Dragon", card_type: "Monster", image: 89631139 },
  {
    id: 3,
    code: 83764718,
    name: "Monster Reborn",
    name_pt: "Renascer do Monstro",
    card_type: "Spell",
    image: 83764718,
  },
];

const STATE = {
  id: 5,
  status: "dueling",
  winner_team: null as number | null,
  seq: 3,
  you: 0,
  players: [
    { team: 0, nickname: "JadenYuki" },
    { team: 1, nickname: "Syrus" },
  ],
  view: {
    you: 0,
    turn: 3,
    turn_team: 1,
    phase: "battle",
    waiting_for: 1,
    sides: [
      {
        team: 0,
        lp: 6500,
        deck: 30,
        extra: 0,
        hand: [{ code: 46986414 }],
        monsters: [
          { code: 89631139, face_down: false, defense: false, atk: 3000, def: 2500 },
          null,
          null,
          null,
          null,
        ],
        spells: [{ code: 83764718, face_down: true, defense: false }, null, null, null, null],
        grave: [{ code: 46986414 }],
        banished: [],
        extra_cards: [],
      },
      {
        team: 1,
        lp: 8000,
        deck: 31,
        extra: 1,
        hand: [{ hidden: true }, { hidden: true }, { hidden: true }],
        monsters: [null, { face_down: true, defense: true }, null, null, null],
        spells: [null, null, null, null, null],
        grave: [],
        banished: [],
      },
    ],
  },
};

// Partida falsa, sem tempo real (o token responde 503): a tela consulta a mesa.
async function mockMatch(page: Page) {
  let current = structuredClone(STATE);
  await page.route("**/api/realtime/token", (route) =>
    route.fulfill({
      status: 503,
      json: { error: { status: 503, message: "O tempo real está desligado." } },
    }),
  );
  await page.route("**/api/cards", (route) => route.fulfill({ json: { data: CARDS } }));
  await page.route("**/api/packs", (route) => route.fulfill({ json: { data: [] } }));
  await page.route("**/api/cards/1", (route) =>
    route.fulfill({
      json: { data: { ...CARDS[0], text: "O mago supremo.", source: "https://yugipedia.com" } },
    }),
  );
  await page.route("**/api/matches/5", (route) => route.fulfill({ json: { data: current } }));
  return { set: (next: typeof STATE) => (current = next) };
}

test.beforeEach(async ({ page }) => mockSession(page, { loggedIn: true }));

test("mostra os dois lados da mesa, escondendo o que é do outro", async ({ page }) => {
  await mockMatch(page);
  await page.goto("/duelo/5");

  await expect(
    page.getByRole("heading", { level: 1, name: "Duelo de JadenYuki contra Syrus" }),
  ).toBeAttached();
  await expect(page.getByText("Turno 3, vez de Syrus")).toBeVisible();
  await expect(
    page.getByRole("list", { name: "Fases do turno" }).getByText("Batalha"),
  ).toHaveAttribute("aria-current", "step");

  const theirs = page.getByRole("region", { name: "Lado de Syrus" });
  await expect(theirs.getByText("PV 8000")).toBeVisible();
  await expect(theirs.getByRole("list", { name: "Mão de Syrus" }).getByRole("img")).toHaveCount(3);
  await expect(
    theirs.getByRole("list", { name: "Monstros de Syrus" }).getByRole("img"),
  ).toHaveAccessibleName("Carta virada para baixo");

  const mine = page.getByRole("region", { name: "Lado de JadenYuki" });
  await expect(mine.getByText("PV 6500")).toBeVisible();
  await expect(mine.getByRole("button", { name: "Blue-Eyes White Dragon" })).toContainText(
    "3000/2500",
  );
  await expect(
    mine.getByRole("button", { name: "Renascer do Monstro, virada para baixo" }),
  ).toBeVisible();
  await expect(page.getByRole("status").filter({ hasText: "Vez de Syrus" })).toBeVisible();

  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("clicar numa carta mostra o detalhe dela", async ({ page }) => {
  await mockMatch(page);
  await page.goto("/duelo/5");
  await page
    .getByRole("list", { name: "Sua mão" })
    .getByRole("button", { name: "Mago Negro" })
    .click();

  await expect(page.getByText("O mago supremo.")).toBeVisible();
});

test("sem tempo real, o fim do duelo aparece na próxima consulta", async ({ page }) => {
  const match = await mockMatch(page);
  await page.goto("/duelo/5");
  await expect(page.getByText("Turno 3, vez de Syrus")).toBeVisible();

  match.set({ ...STATE, status: "finished", winner_team: 0 });
  await expect(page.getByRole("status").filter({ hasText: "Você venceu!" })).toBeVisible({
    timeout: 5000,
  });
});
