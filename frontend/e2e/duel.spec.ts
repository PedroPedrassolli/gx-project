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
// O detalhe de todas as cartas, pelo id (GXP-121).
const DETAILS = {
  1: { text: "O mago supremo.", source: "https://yugipedia.com" },
  2: { text: "Um dragão lendário.", source: "https://yugipedia.com" },
  3: { text: "Escolha 1 monstro em qualquer Cemitério.", source: "https://yugipedia.com" },
};

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
  await page.route("**/api/cards/details", (route) => route.fulfill({ json: { data: DETAILS } }));
  await page.route("**/api/matches/5", (route) => route.fulfill({ json: { data: current } }));
  return { set: (next: unknown) => (current = next as typeof STATE) };
}

test.beforeEach(async ({ page }) => mockSession(page, { loggedIn: true }));

test("de qualquer página, o aviso leva de volta ao duelo em andamento", async ({ page }) => {
  await mockSession(page, { loggedIn: true, duel: { match_id: 5, room_code: "ABC234" } });
  await mockMatch(page);
  await page.goto("/cartas");

  const notice = page.getByRole("status").filter({ hasText: "Você tem um duelo em andamento." });
  await notice.getByRole("link", { name: "Voltar para a mesa" }).click();
  await expect(page).toHaveURL(/\/duelo\/5$/);
  await expect(page.getByText("Turno 3, vez de Syrus")).toBeVisible();
  // Na própria mesa, o aviso some.
  await expect(notice).toHaveCount(0);
});

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
  await expect(
    mine.getByRole("button", { name: "Blue-Eyes White Dragon, ATK 3000, DEF 2500" }),
  ).toBeVisible();
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

test("o texto de todas as cartas vem num pedido só, sem esperar o toque", async ({ page }) => {
  await mockMatch(page);
  const asked: string[] = [];
  page.on("request", (request) => {
    const path = new URL(request.url()).pathname;
    if (path.startsWith("/api/cards/")) asked.push(path);
  });
  await page.goto("/duelo/5");

  // Ninguém tocou em nada: o detalhe de todas as cartas já chegou, num pedido só.
  await expect.poll(() => asked).toEqual(["/api/cards/details"]);
  await page
    .getByRole("list", { name: "Monstros de JadenYuki" })
    .getByRole("button", { name: /Blue-Eyes White Dragon/ })
    .click();
  await expect(page.getByRole("heading", { name: "Blue-Eyes White Dragon" })).toBeVisible();
  await expect(page.getByText("Um dragão lendário.")).toBeVisible();
  expect(asked).toEqual(["/api/cards/details"]);
});

test("enquanto o texto de todas não chega, a carta tocada pede o dela", async ({ page }) => {
  await mockMatch(page);
  // O pedido de todas demora: a carta aparece antes, com o nome e os números.
  await page.route("**/api/cards/details", async (route) => {
    await new Promise((done) => setTimeout(done, 4000));
    await route.fulfill({ json: { data: DETAILS } });
  });
  await page.route("**/api/cards/2", async (route) => {
    await new Promise((done) => setTimeout(done, 1000));
    await route.fulfill({
      json: { data: { ...CARDS[1], text: "Um dragão lendário.", source: "https://yugipedia.com" } },
    });
  });
  await page.goto("/duelo/5");
  await page
    .getByRole("list", { name: "Monstros de JadenYuki" })
    .getByRole("button", { name: /Blue-Eyes White Dragon/ })
    .click();
  await expect(page.getByRole("heading", { name: "Blue-Eyes White Dragon" })).toBeVisible();
  await expect(page.getByText("Carregando o texto…")).toBeVisible();
  await expect(page.getByText("Um dragão lendário.")).toBeVisible({ timeout: 3_000 });
});

test("sem tempo real, o fim do duelo aparece na próxima consulta", async ({ page }) => {
  const match = await mockMatch(page);
  await page.goto("/duelo/5");
  await expect(page.getByText("Turno 3, vez de Syrus")).toBeVisible();

  match.set({ ...STATE, status: "finished", winner_team: 0 });
  await expect(page.getByRole("status").filter({ hasText: "Você venceu!" })).toBeVisible({
    timeout: 5000,
  });
  await expect(page.getByText("Turno 3, duelo encerrado")).toBeVisible();
  await expect(
    page.getByRole("list", { name: "Fases do turno" }).locator("[aria-current]"),
  ).toHaveCount(0);
});

test("na mesa, o monstro mostra o ATK em ataque e o DEF em defesa", async ({ page }) => {
  const match = await mockMatch(page);
  const [mine, theirs] = STATE.view.sides;
  const guard = { code: 46986414, face_down: false, defense: true, atk: 2500, def: 2100 };
  const sides = [
    { ...mine, monsters: [mine?.monsters[0] ?? null, guard, null, null, null] },
    theirs,
  ];
  match.set({ ...STATE, view: { ...STATE.view, sides } });
  await page.goto("/duelo/5");

  const monsters = page.getByRole("list", { name: "Monstros de JadenYuki" });
  await expect(
    monsters.getByRole("button", { name: "Mago Negro, em defesa, ATK 2500, DEF 2100" }),
  ).toBeVisible();
  await expect(monsters.getByText("3000", { exact: true })).toBeVisible();
  await expect(monsters.getByText("2100", { exact: true })).toBeVisible();
  await expect(monsters.getByText("2500", { exact: true })).toHaveCount(0);
});

test("do resultado, volta para a sala reaberta sem cair de novo na mesa", async ({ page }) => {
  const match = await mockMatch(page);
  const seat = { ready: true, deck_chosen: true };
  let room: Record<string, unknown> = {
    code: "ABC234",
    public: false,
    mode: "1x1",
    best_of: 1,
    banlist: true,
    destiny_draw: false,
    decision_seconds: 90,
    duel_minutes: 60,
    status: "dueling",
    owner_id: 1,
    seats: 2,
    match_id: 5,
    players: [
      { ...seat, seat: 0, user_id: 1, nickname: "JadenYuki", deck_id: 7 },
      { ...seat, seat: 1, user_id: 2, nickname: "Syrus" },
    ],
  };
  await page.route("**/api/rooms/ABC234", (route) => route.fulfill({ json: { data: room } }));
  await page.route("**/api/decks", (route) =>
    route.fulfill({
      json: { data: [{ id: 7, name: "Heróis", updated_at: "2026-11-14T12:00:00Z" }] },
    }),
  );
  // Sala em duelo leva à mesa.
  await page.goto("/salas/ABC234");
  await expect(page).toHaveURL(/\/duelo\/5$/);

  match.set({ ...STATE, status: "finished", winner_team: 0, room_code: "ABC234" });
  room = { ...room, status: "waiting", match_id: null };
  await page.getByRole("link", { name: "Voltar para a sala" }).click();
  await expect(page.getByRole("heading", { level: 1, name: "Sala ABC234" })).toBeVisible();
  await expect(page).toHaveURL(/\/salas\/ABC234$/);
});

test("revanche: um clique deixa pronto com o mesmo deck e volta para a sala", async ({ page }) => {
  const match = await mockMatch(page);
  match.set({ ...STATE, status: "finished", winner_team: 0, room_code: "ABC234" });
  const room = {
    code: "ABC234",
    public: false,
    mode: "1x1",
    best_of: 1,
    banlist: true,
    destiny_draw: false,
    decision_seconds: 90,
    duel_minutes: 60,
    status: "waiting",
    owner_id: 1,
    seats: 2,
    players: [
      { seat: 0, user_id: 1, nickname: "JadenYuki", ready: true, deck_chosen: true, deck_id: 7 },
      { seat: 1, user_id: 2, nickname: "Syrus", ready: false, deck_chosen: true },
    ],
  };
  const sent: unknown[] = [];
  let closed = false;
  await page.route("**/api/rooms/ABC234/ready", (route) => {
    sent.push(route.request().postDataJSON());
    if (closed) {
      return route.fulfill({
        status: 404,
        json: { error: { status: 404, message: "Não encontrado." } },
      });
    }
    return route.fulfill({ json: { data: room } });
  });
  await page.route("**/api/rooms/ABC234", (route) => route.fulfill({ json: { data: room } }));
  await page.route("**/api/decks", (route) =>
    route.fulfill({
      json: { data: [{ id: 7, name: "Heróis", updated_at: "2026-11-14T12:00:00Z" }] },
    }),
  );

  // A sala que fechou avisa, e a tela fica no resultado.
  closed = true;
  await page.goto("/duelo/5");
  await page.getByRole("button", { name: "Revanche" }).click();
  await expect(page.getByRole("alert")).toHaveText("A sala fechou: quem criou saiu.");

  closed = false;
  await page.getByRole("button", { name: "Revanche" }).click();
  await expect(page).toHaveURL(/\/salas\/ABC234$/);
  await expect(page.getByRole("button", { name: "Não estou pronto" })).toBeVisible();
  expect(sent).toEqual([{ ready: true }, { ready: true }]);
});

test("as frases: a sua aparece no seu nome, e a do outro chega na consulta", async ({ page }) => {
  const match = await mockMatch(page);
  const sent: unknown[] = [];
  await page.route("**/api/matches/5/emotes", (route) => {
    sent.push(route.request().postDataJSON());
    const emote_at = new Date().toISOString();
    return route.fulfill({ json: { data: { id: 5, team: 0, emote: "nice", emote_at } } });
  });
  await page.goto("/duelo/5");

  await page.getByRole("button", { name: "Frases" }).click();
  await page
    .getByRole("dialog", { name: "Frases" })
    .getByRole("button", { name: "Boa jogada!" })
    .click();
  await expect(page.getByRole("status").filter({ hasText: "Boa jogada!" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Bom duelo!" })).toBeHidden();
  expect(sent).toEqual([{ emote: "nice" }]);

  const emote_at = new Date().toISOString();
  const players = STATE.players.map((player) =>
    player.team === 1 ? { ...player, emote: "gg", emote_at } : player,
  );
  match.set({ ...STATE, players });
  await expect(page.getByRole("status").filter({ hasText: "Bom duelo!" })).toBeVisible();
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("'sempre perguntar' na corrente fica no navegador e vai para cada duelo", async ({ page }) => {
  const match = await mockMatch(page);
  match.set({ ...STATE, always_chain: false });
  const sent: unknown[] = [];
  await page.route("**/api/matches/5/settings", (route) => {
    const body = route.request().postDataJSON();
    sent.push(body);
    match.set({ ...STATE, always_chain: body.always_chain });
    return route.fulfill({ status: 204 });
  });
  await page.goto("/duelo/5");

  await page.getByLabel("Perguntar na corrente").selectOption("Sempre");
  await expect.poll(() => sent).toEqual([{ always_chain: true }]);

  // Duelo novo: a mesa ainda não sabe, e o navegador manda a escolha de novo.
  match.set({ ...STATE, always_chain: false });
  await page.reload();
  await expect(page.getByLabel("Perguntar na corrente")).toHaveValue("always");
  await expect.poll(() => sent).toEqual([{ always_chain: true }, { always_chain: true }]);
});

test("o resultado mostra o DP do duelo linha por linha, com os cortes e o saldo", async ({
  page,
}) => {
  const match = await mockMatch(page);
  const line = (key: string, label: string, dp: number) => ({ key, label, dp });
  const rewards = {
    lines: [
      line("level", "Nível 1", 2),
      line("turns", "6 turnos", 12),
      line("network_win", "Vitória em rede", 50),
    ],
    cuts: [line("daily_cap", "Teto de 15.000 DP por dia em duelos", -32)],
    level_ups: [line("level_up", "Subiu para o nível 2", 400)],
    challenges: [{ number: 26, label: "Empatar um duelo" }],
    missions: [
      { name: "Torneio Slifer Red", card: null, packs: ["Test of Luck", "Power of the Heroes"] },
      { name: "Carta da semana", card: "Toon Kingdom", packs: [] },
    ],
    total: 432,
    level: 2,
    balance: 1666,
  };
  match.set({ ...STATE, status: "finished", winner_team: 0, finish_reason: "surrender", rewards });
  await page.goto("/duelo/5");

  const table = page.getByRole("table", { name: "DP do duelo" });
  await expect(table.getByRole("row")).toHaveText([
    "Nível 1+2 DP",
    "6 turnos+12 DP",
    "Vitória em rede+50 DP",
    "Teto de 15.000 DP por dia em duelos−32 DP",
    "Subiu para o nível 2+400 DP",
    "Total+432 DP",
  ]);
  await expect(page.getByText("Saldo: 1.666 DP. Nível 2.")).toBeVisible();
  // O resultado abre sozinho num modal, à vista, sem procurar embaixo da mesa (GXP-99).
  const result = page.getByRole("dialog", { name: "Você venceu!" });
  await expect(result.getByRole("table", { name: "DP do duelo" })).toBeInViewport();
  await expect(
    page.getByRole("link", { name: "Missão concluída: Torneio Slifer Red" }),
  ).toBeVisible();
  await expect(
    page.getByText("Pacotes liberados na loja: Test of Luck e Power of the Heroes."),
  ).toBeVisible();
  await expect(page.getByText("Você ganhou a carta Toon Kingdom.")).toBeVisible();
  await expect(page.getByRole("link", { name: "Desafio concluído" })).toHaveAttribute(
    "href",
    "/desafios",
  );
  await expect(page.getByText("Empatar um duelo")).toBeVisible();
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);

  // "Ver a mesa" fecha o modal, e a faixa das fases tem o caminho de volta.
  await result.getByRole("button", { name: "Ver a mesa" }).click();
  await expect(result).toBeHidden();
  await page.getByRole("button", { name: "Ver o resultado" }).click();
  await expect(result).toBeVisible();
});

test("contra personagem: sem frases, e o resultado mostra a carta ganha e o próximo", async ({
  page,
}) => {
  const match = await mockMatch(page);
  const players = [
    { team: 0, nickname: "JadenYuki" },
    { team: 1, nickname: "Chumley" },
  ];
  match.set({ ...STATE, character: "chumley", players });
  await page.goto("/duelo/5");
  await expect(page.getByRole("status")).toContainText("Vez de Chumley");
  await expect(page.getByRole("button", { name: "Frases" })).toHaveCount(0);

  const rewards = {
    lines: [{ key: "character", label: "Vitória contra Chumley", dp: 60 }],
    cuts: [],
    level_ups: [],
    card: { id: 1, name: "Dark Magician", name_pt: "Mago Negro", image: 46986414 },
    unlocked: { id: "syrus", name: "Syrus" },
    total: 60,
    level: 2,
    balance: 1294,
  };
  match.set({
    ...STATE,
    character: "chumley",
    players,
    status: "finished",
    winner_team: 0,
    finish_reason: "duel",
    rewards,
  });
  await page.reload();
  const result = page.getByRole("dialog", { name: "Você venceu!" });
  await expect(result.getByText(/Você ganhou a carta (Mago Negro|Dark Magician)!/)).toBeVisible();
  await expect(result.getByText("Personagem liberado: Syrus.")).toBeVisible();
  await expect(result.getByRole("link", { name: "Duelar contra Syrus" })).toHaveAttribute(
    "href",
    "/personagens?duelar=syrus",
  );
  await expect(result.getByRole("link", { name: "Duelar de novo" })).toHaveAttribute(
    "href",
    "/personagens?duelar=chumley",
  );
  await expect(result.getByRole("link", { name: "Revanche" })).toHaveCount(0);
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("o replay passa lance a lance e turno a turno, e reproduz sozinho", async ({ page }) => {
  await mockMatch(page);
  const frame = (step: number, turn: number, lp: number) => ({
    step,
    view: {
      ...STATE.view,
      turn,
      sides: [STATE.view.sides[0], { ...STATE.view.sides[1], lp }],
      events: [{ id: step, type: "lp", team: 1, kind: "damage", amount: 100 }],
    },
  });
  const turns: Record<string, unknown[]> = {
    "1": [frame(0, 1, 8000), frame(2, 1, 7900)],
    "2": [frame(5, 2, 7800)],
  };
  const asked: string[] = [];
  await page.route(/\/api\/matches\/5\/replay/, (route) => {
    const turn = new URL(route.request().url()).searchParams.get("turn") ?? "1";
    asked.push(turn);
    return route.fulfill({
      json: {
        data: {
          id: 5,
          turn: Number(turn),
          turns: 2,
          you: 0,
          players: STATE.players,
          frames: turns[turn],
        },
      },
    });
  });
  await page.goto("/duelo/5/replay");

  const theirs = page.getByRole("region", { name: "Lado de Syrus" });
  await expect(page.getByText("Turno 1 de 2")).toBeVisible();
  await expect(page.getByText("Lance 1 de 2")).toBeVisible();
  await expect(page.getByRole("button", { name: "Anterior" })).toBeDisabled();
  await page.getByRole("button", { name: "Próximo" }).click();
  await expect(theirs.getByText("PV 7900")).toBeVisible();
  // O histórico é o do turno até o lance.
  await expect(
    page.getByRole("region", { name: "Histórico" }).getByText("Syrus perdeu 100 PV."),
  ).toHaveCount(2);

  await page.getByRole("button", { name: "Próximo" }).click();
  await expect(page.getByText("Turno 2 de 2")).toBeVisible();
  await expect(theirs.getByText("PV 7800")).toBeVisible();
  await expect(page.getByRole("button", { name: "Próximo" })).toBeDisabled();

  // Voltar do começo de um turno leva ao último lance do anterior.
  await page.getByRole("button", { name: "Anterior" }).click();
  await expect(page.getByText("Lance 2 de 2")).toBeVisible();
  await expect(page.getByText("Turno 1 de 2")).toBeVisible();

  await page.getByLabel("Ir para o turno").selectOption("1");
  await expect(page.getByText("Lance 1 de 2")).toBeVisible();
  await page.getByRole("button", { name: "Reproduzir" }).click();
  await expect(page.getByRole("button", { name: "Pausar" })).toBeVisible();
  await expect(page.getByText("Turno 2 de 2")).toBeVisible({ timeout: 6000 });
  await expect(page.getByRole("button", { name: "Reproduzir" })).toBeDisabled();
  expect([...new Set(asked)].sort()).toEqual(["1", "2"]);
});

test("o resultado leva ao replay; antes do fim, o replay avisa que não está pronto", async ({
  page,
}) => {
  const match = await mockMatch(page);
  match.set({ ...STATE, status: "finished", winner_team: 0, finish_reason: "surrender" });
  await page.route(/\/api\/matches\/5\/replay/, (route) =>
    route.fulfill({
      status: 409,
      json: { error: { status: 409, message: "O replay fica pronto quando o duelo acaba." } },
    }),
  );
  await page.goto("/duelo/5");
  await page.getByRole("link", { name: "Ver o replay" }).click();
  await expect(page).toHaveURL(/\/duelo\/5\/replay$/);
  await expect(page.getByRole("alert")).toHaveText("O replay fica pronto quando o duelo acaba.");
  await expect(page.getByRole("link", { name: "Voltar para o duelo" })).toHaveAttribute(
    "href",
    "/duelo/5",
  );
});

test("animações: o que chega depois de abrir anima; desligadas, nada anima", async ({ page }) => {
  // Anota onde cada animação do Web Animations API rodou (ataque, cemitério).
  await page.addInitScript(() => {
    const places: string[] = [];
    Object.assign(window, { animatedPlaces: places });
    const original = Element.prototype.animate;
    Element.prototype.animate = function (this: Element, ...args: Parameters<Element["animate"]>) {
      places.push(this.closest("[data-place]")?.getAttribute("data-place") ?? "");
      return original.apply(this, args);
    };
  });
  const match = await mockMatch(page);
  const old = [{ id: 1, type: "lp", team: 1, kind: "damage", amount: 300 }];
  match.set({ ...STATE, view: { ...STATE.view, events: old } });
  await page.goto("/duelo/5");
  await expect(page.getByText("Turno 3, vez de Syrus")).toBeVisible();
  // O que já estava no histórico ao abrir fica parado.
  await expect(page.locator(".lp-change")).toHaveCount(0);
  await expect(page.locator("main")).toHaveAttribute("data-motion", "normal");

  const attacker = { controller: 0, location: 4, sequence: 0, position: 1, code: 89631139 };
  const grave = { controller: 1, location: 16, sequence: 0, position: 1 };
  const news = [
    { id: 2, type: "attack", attacker, target: null },
    { id: 3, type: "lp", team: 1, kind: "damage", amount: 3000 },
    { id: 4, type: "move", code: 46986414, from: { ...grave, location: 2 }, to: grave, reason: 1 },
  ];
  match.set({ ...STATE, view: { ...STATE.view, events: [...old, ...news] } });
  await expect(page.locator('[data-lp="1"] .lp-change')).toHaveText("−3.000", { timeout: 5000 });
  await expect
    .poll(() =>
      page.evaluate(() => (window as unknown as { animatedPlaces: string[] }).animatedPlaces),
    )
    .toEqual(["0-4-0", "1-16"]);

  await page.getByLabel("Animações").selectOption("Desligadas");
  await expect(page.locator(".lp-change")).toHaveCount(0);
  await expect(page.locator("main")).toHaveAttribute("data-motion", "off");
  expect(await page.evaluate(() => localStorage.getItem("gx-animacoes-do-duelo"))).toBe("off");
});

test("as pilhas abrem a lista: cemitério, banidas e o seu Extra", async ({ page }) => {
  const match = await mockMatch(page);
  const [mine, theirs] = STATE.view.sides;
  const sides = [
    { ...mine, extra: 1, extra_cards: [{ code: 89631139 }] },
    { ...theirs, banished: [{ code: 83764718 }, { hidden: true }] },
  ];
  match.set({ ...STATE, view: { ...STATE.view, sides } });
  await page.goto("/duelo/5");

  await page.getByRole("button", { name: "Banidas 2" }).click();
  const banished = page.getByRole("dialog", { name: "Cartas banidas de Syrus (2)" });
  await expect(banished.getByText("Carta virada para baixo")).toBeVisible();
  await expect(banished.getByRole("button", { name: "Renascer do Monstro" })).toBeVisible();
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
  await page.keyboard.press("Escape");
  await expect(banished).toBeHidden();

  await page.getByRole("button", { name: "Seu Extra, 1 carta" }).click();
  const extra = page.getByRole("dialog", { name: "Seu Extra (1)" });
  await expect(extra.getByRole("button", { name: "Blue-Eyes White Dragon" })).toBeVisible();
  await extra.getByRole("button", { name: "Fechar" }).click();
  await expect(extra).toBeHidden();

  await page.getByRole("button", { name: "Seu cemitério, 1 carta" }).click();
  await page
    .getByRole("dialog", { name: "Seu cemitério (1)" })
    .getByRole("button", { name: "Mago Negro" })
    .click();
  await expect(page.getByText("O mago supremo.")).toBeVisible();
});

test("o histórico conta as jogadas e a corrente mostra os elos abertos", async ({ page }) => {
  const match = await mockMatch(page);
  const spell = { code: 83764718, controller: 0, location: 8, sequence: 0, position: 1 };
  const events = [
    { id: 7, type: "turn", team: 1 },
    { id: 8, type: "phase", phase: 0x10 },
    {
      id: 9,
      type: "summon",
      kind: "normal",
      code: 89631139,
      controller: 1,
      location: 4,
      sequence: 1,
      position: 1,
    },
    { id: 10, type: "chain", ...spell, link: 1, description: 1 },
  ];
  const chain = [
    { ...spell, link: 1, description: 1, text: "Special Summon 1 monster", negated: true },
  ];
  match.set({ ...STATE, view: { ...STATE.view, events, chain } });
  await page.goto("/duelo/5");

  await expect(page.getByRole("region", { name: "Histórico" }).getByRole("listitem")).toHaveText([
    "Elo 1: você ativou Renascer do Monstro.",
    "Syrus invocou Blue-Eyes White Dragon.",
    "Novo turno: vez de Syrus.",
  ]);
  const stack = page.getByRole("region", { name: "Corrente" });
  await expect(stack.getByRole("listitem")).toContainText("Renascer do Monstro, sua");
  await expect(stack).toContainText("negado");
  await expect(stack).toContainText("Special Summon 1 monster");
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("mostra quanto falta para responder e para o fim do duelo", async ({ page }) => {
  const match = await mockMatch(page);
  const now = Date.now();
  match.set({
    ...STATE,
    deadline_at: new Date(now + 75_000).toISOString(),
    ends_at: new Date(now + 50 * 60_000).toISOString(),
  });
  await page.goto("/duelo/5");

  await expect(page.getByRole("timer").filter({ hasText: "Resposta" })).toHaveText(
    /Resposta: 1:1\d/,
  );
  await expect(page.getByRole("timer").filter({ hasText: "Duelo" })).toHaveText(/Duelo: 49:5\d/);
});

test("sala sem limite de tempo: a mesa não mostra relógio", async ({ page }) => {
  const match = await mockMatch(page);
  match.set({ ...STATE, deadline_at: null, ends_at: null });
  await page.goto("/duelo/5");

  await expect(page.getByText("Sem limite de tempo")).toBeVisible();
  await expect(page.getByRole("timer")).toHaveCount(0);
});

test("desistir pede confirmação e mostra o resultado com a volta para a sala", async ({ page }) => {
  await mockMatch(page);
  const sent: string[] = [];
  await page.route("**/api/matches/5/surrender", (route) => {
    sent.push(route.request().method());
    return route.fulfill({
      json: {
        data: {
          ...STATE,
          status: "finished",
          winner_team: 1,
          finish_reason: "surrender",
          room_code: "ABC234",
        },
      },
    });
  });
  await page.goto("/duelo/5");

  await page.getByRole("button", { name: "Desistir" }).click();
  const dialog = page.getByRole("dialog", { name: "Desistir do duelo?" });
  await expect(dialog.getByRole("button", { name: "Continuar jogando" })).toBeFocused();
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
  await dialog.getByRole("button", { name: "Continuar jogando" }).click();
  await expect(dialog).toBeHidden();
  expect(sent).toEqual([]);

  await page.getByRole("button", { name: "Desistir" }).click();
  await dialog.getByRole("button", { name: "Desistir" }).click();
  await expect(page.getByRole("heading", { name: "Syrus venceu." })).toBeVisible();
  await expect(page.getByText("Você desistiu.")).toBeVisible();
  await expect(page.getByRole("link", { name: "Voltar para a sala" })).toHaveAttribute(
    "href",
    "/salas/ABC234",
  );
  expect(sent).toEqual(["POST"]);
});

test("com o prazo vencido, a tela consulta e mostra quem venceu por tempo", async ({ page }) => {
  const match = await mockMatch(page);
  match.set({ ...STATE, deadline_at: new Date(Date.now() + 1_500).toISOString() });
  await page.goto("/duelo/5");
  await expect(page.getByRole("timer").filter({ hasText: "Resposta" })).toBeVisible();

  match.set({ ...STATE, status: "finished", winner_team: 0, finish_reason: "timeout" });
  await expect(page.getByRole("heading", { name: "Você venceu!" })).toBeVisible({ timeout: 5000 });
  await expect(page.getByText("Syrus deixou o tempo acabar.")).toBeVisible();
  await expect(page.getByRole("link", { name: "Ver as salas" })).toBeVisible();
});

// A vez é do jogador: a mesa traz a pergunta e o servidor responde com a mesa nova.
// A resposta vai depois do clique, sem esperar por ela: os testes conferem com expect.poll.
async function mockPrompt(page: Page, prompt: Record<string, unknown>, reply = { status: 200 }) {
  const sent: unknown[] = [];
  const mine = { ...STATE, view: { ...STATE.view, turn_team: 0, waiting_for: 0, prompt } };
  await mockMatch(page);
  await page.route("**/api/matches/5", (route) => route.fulfill({ json: { data: mine } }));
  await page.route("**/api/matches/5/responses", (route) => {
    sent.push(route.request().postDataJSON());
    if (reply.status !== 200) {
      return route.fulfill({
        status: reply.status,
        json: { error: { status: reply.status, message: "Essa jogada não vale agora." } },
      });
    }
    return route.fulfill({ json: { data: { ...STATE, seq: 4 } } });
  });
  return sent;
}

const IDLE = {
  type: "select_idlecmd",
  player: 0,
  summonable: [{ code: 46986414, controller: 0, location: 2, sequence: 0 }],
  spsummonable: [],
  repositionable: [],
  msetable: [],
  ssetable: [],
  activatable: [
    {
      code: 83764718,
      controller: 0,
      location: 2,
      sequence: 1,
      description: 1,
      text: "Special Summon 1 monster",
    },
  ],
  to_bp: true,
  to_ep: true,
};

test("na fase principal, a carta que brilha abre as ações dela, e a escolha vai para o servidor", async ({
  page,
}) => {
  const sent = await mockPrompt(page, IDLE);
  await page.goto("/duelo/5");

  // A carta que dá para usar brilha na mão; a mão do outro, não.
  const hand = page.getByRole("list", { name: "Sua mão" });
  await expect(hand.getByRole("listitem")).toHaveAttribute("data-actionable", "true");
  await expect(page.locator(".side.opponent [data-actionable]")).toHaveCount(0);
  // Ir para a Batalha e encerrar o turno ficam na faixa das fases, à vista, sem rolar.
  await expect(page.getByRole("button", { name: "Ir para a Batalha" })).toBeInViewport();
  await expect(page.getByRole("button", { name: "Encerrar o turno" })).toBeInViewport();

  // "Todas as ações" traz também a carta que não está à vista na mesa.
  await page.getByRole("button", { name: "Todas as ações" }).click();
  const all = page.getByRole("dialog", { name: "Fase principal: o que fazer?" });
  await expect(all.getByRole("button", { name: "Ativar Renascer do Monstro (mão)" })).toContainText(
    "Special Summon 1 monster",
  );
  await all.getByRole("button", { name: "Fechar" }).click();
  await expect(all).toBeHidden();

  await hand.getByRole("button", { name: "Mago Negro" }).click();
  const actions = page.getByRole("dialog", { name: "Mago Negro" });
  await expect(actions.getByRole("button", { name: "Invocar" })).toBeVisible();
  await expect(actions.getByText("O mago supremo.")).toBeVisible();
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);

  await actions.getByRole("button", { name: "Invocar" }).click();
  await expect(page.getByRole("status").filter({ hasText: "Vez de Syrus" })).toBeVisible();
  await expect.poll(() => sent).toEqual([{ seq: 3, response: { command: "summon", index: 0 } }]);
});

test("a mesa cheia cabe na tela, sem rolar, do celular pequeno ao notebook", async ({ page }) => {
  const full = {
    ...STATE.view,
    turn_team: 0,
    waiting_for: 0,
    prompt: IDLE,
    sides: STATE.view.sides.map((side) =>
      side.team === 0
        ? { ...side, hand: Array.from({ length: 7 }, () => ({ code: 46986414 })) }
        : { ...side, hand: Array.from({ length: 6 }, () => ({ hidden: true })) },
    ),
  };
  await mockMatch(page);
  await page.route("**/api/matches/5", (route) =>
    route.fulfill({ json: { data: { ...STATE, view: full } } }),
  );
  const sizes: [number, number][] = [
    [360, 640],
    [390, 844],
    [1280, 720],
    [1920, 1080],
  ];
  for (const [width, height] of sizes) {
    await page.setViewportSize({ width, height });
    await page.goto("/duelo/5");
    await expect(page.getByRole("button", { name: "Encerrar o turno" })).toBeInViewport();
    const fit = await page.evaluate(() => ({
      page: document.documentElement.scrollHeight - innerHeight,
      wide: document.documentElement.scrollWidth - document.documentElement.clientWidth,
      board:
        Math.ceil(document.querySelector(".board")!.getBoundingClientRect().bottom) - innerHeight,
    }));
    expect(fit.page, `rolagem em ${width}x${height}`).toBeLessThanOrEqual(0);
    expect(fit.wide, `largura em ${width}x${height}`).toBeLessThanOrEqual(0);
    expect(fit.board, `mesa em ${width}x${height}`).toBeLessThanOrEqual(0);
  }
});

test("a pergunta abre num modal que dá para minimizar e abrir de novo", async ({ page }) => {
  const sent = await mockPrompt(page, {
    type: "select_effectyn",
    player: 0,
    code: 46986414,
    controller: 0,
    location: 4,
    sequence: 0,
    text: "Ativar o efeito do Mago Negro?",
  });
  await page.goto("/duelo/5");
  const dialog = page.getByRole("dialog", { name: "Ativar o efeito do Mago Negro?" });
  await expect(dialog).toBeVisible();

  await dialog.getByRole("button", { name: "Ver a mesa" }).click();
  await expect(dialog).toBeHidden();
  // Com o modal minimizado, a mesa responde ao toque e a faixa das fases tem o caminho de volta.
  await page.getByRole("button", { name: "Responder: Ativar o efeito do Mago Negro?" }).click();
  await expect(dialog).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(dialog).toBeHidden();
  await page.getByRole("button", { name: "Responder: Ativar o efeito do Mago Negro?" }).click();
  await dialog.getByRole("button", { name: "Sim" }).click();
  await expect.poll(() => sent).toEqual([{ seq: 3, response: { yes: true } }]);
});

test("jogada que o servidor recusa mostra o aviso", async ({ page }) => {
  await mockPrompt(page, IDLE, { status: 422 });
  await page.goto("/duelo/5");
  await page.getByRole("button", { name: "Encerrar o turno" }).click();

  await expect(page.getByRole("alert")).toHaveText("Essa jogada não vale agora.");
});

test("cadeia, sim ou não e posição mandam a escolha certa", async ({ page }) => {
  const chain = await mockPrompt(page, {
    type: "select_chain",
    player: 0,
    forced: false,
    chains: [
      { code: 83764718, controller: 0, location: 8, sequence: 0, description: 1, text: null },
    ],
  });
  await page.goto("/duelo/5");
  await page.getByRole("button", { name: "Não encadear" }).click();
  await expect.poll(() => chain).toEqual([{ seq: 3, response: { index: -1 } }]);

  const yesNo = await mockPrompt(page, {
    type: "select_yesno",
    player: 0,
    description: 9,
    text: "Usar o Destiny Draw?",
  });
  await page.goto("/duelo/5");
  await page
    .getByRole("dialog", { name: "Usar o Destiny Draw?" })
    .getByRole("button", { name: "Sim" })
    .click();
  await expect.poll(() => yesNo).toEqual([{ seq: 3, response: { yes: true } }]);

  // Sem texto de carta, vale o texto do próprio jogo (antes aparecia "Confirmar?").
  const direct = await mockPrompt(page, { type: "select_yesno", player: 0, description: 31 });
  await page.goto("/duelo/5");
  await page
    .getByRole("dialog", { name: "Atacar diretamente?" })
    .getByRole("button", { name: "Não" })
    .click();
  await expect.poll(() => direct).toEqual([{ seq: 3, response: { yes: false } }]);

  // Opções que são textos do jogo: "Sim" e "Não", não "Opção 1" e "Opção 2".
  const option = await mockPrompt(page, {
    type: "select_option",
    player: 0,
    options: [1213, 1214],
    options_text: [null, null],
  });
  await page.goto("/duelo/5");
  await expect(page.getByRole("button", { name: "Opção 1" })).toHaveCount(0);
  await page.getByRole("button", { name: "Não" }).click();
  await expect.poll(() => option).toEqual([{ seq: 3, response: { index: 1 } }]);

  const position = await mockPrompt(page, {
    type: "select_position",
    player: 0,
    code: 46986414,
    positions: 0x1 | 0x8,
  });
  await page.goto("/duelo/5");
  await expect(page.getByRole("button", { name: "Ataque, com a face para baixo" })).toHaveCount(0);
  await page.getByRole("button", { name: "Defesa, com a face para baixo" }).click();
  await expect.poll(() => position).toEqual([{ seq: 3, response: { position: 8 } }]);
});

test("escolher cartas: tocar mostra a carta e só o Confirmar responde", async ({ page }) => {
  // Buscar no deck (GXP-79): marcar mostra o detalhe da carta; a resposta vai no Confirmar.
  const search = await mockPrompt(page, {
    type: "select_card",
    player: 0,
    cancelable: true,
    min: 1,
    max: 1,
    hint: 506,
    cards: [
      { code: 89631139, controller: 0, location: 1, sequence: 7 },
      { code: 46986414, controller: 0, location: 1, sequence: 3 },
    ],
  });
  await page.goto("/duelo/5");
  const pick = page.getByRole("dialog", { name: "Escolha a carta para adicionar à mão" });
  await expect(pick.getByRole("button", { name: "Confirmar" })).toBeDisabled();
  await pick.getByRole("radio", { name: "Mago Negro (deck)" }).check();
  await expect(page.getByText("O mago supremo.")).toBeVisible();
  await pick.getByRole("radio", { name: "Blue-Eyes White Dragon (deck)" }).check();
  await expect(pick.getByRole("radio", { name: "Mago Negro (deck)" })).not.toBeChecked();
  await pick.getByRole("radio", { name: "Mago Negro (deck)" }).check();
  expect(search).toEqual([]);
  await pick.getByRole("button", { name: "Confirmar" }).click();
  await expect.poll(() => search).toEqual([{ seq: 3, response: { indexes: [1] } }]);

  const target = await mockPrompt(page, {
    type: "select_card",
    player: 0,
    cancelable: true,
    min: 1,
    max: 1,
    hint: 549,
    cards: [{ code: 89631139, controller: 1, location: 4, sequence: 0 }],
  });
  await page.goto("/duelo/5");
  const attack = page.getByRole("dialog", { name: "Escolha o alvo do ataque" });
  await expect(attack.getByRole("button", { name: "Cancelar" })).toBeVisible();
  await attack
    .getByRole("radio", {
      name: "Blue-Eyes White Dragon (zona de monstro do oponente, 5ª da esquerda)",
    })
    .check();
  await attack.getByRole("button", { name: "Confirmar" }).click();
  await expect.poll(() => target).toEqual([{ seq: 3, response: { indexes: [0] } }]);

  const destroy = await mockPrompt(page, {
    type: "select_card",
    player: 0,
    cancelable: false,
    min: 2,
    max: 2,
    hint: 502,
    cards: [
      { code: 46986414, controller: 0, location: 2, sequence: 0 },
      { code: 83764718, controller: 0, location: 16, sequence: 0 },
    ],
  });
  await page.goto("/duelo/5");
  const panel = page.getByRole("dialog", { name: "Escolha a carta para destruir" });
  const confirm = panel.getByRole("button", { name: "Confirmar" });
  await panel.getByRole("checkbox", { name: "Mago Negro (mão)" }).check();
  await expect(confirm).toBeDisabled();
  await panel.getByRole("checkbox", { name: "Renascer do Monstro (cemitério)" }).check();
  await expect(panel.getByText("Escolhidas: 2 de 2")).toBeVisible();
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
  await confirm.click();
  await expect.poll(() => destroy).toEqual([{ seq: 3, response: { indexes: [0, 1] } }]);
});

test("tributo e soma mandam a escolha certa", async ({ page }) => {
  const field = (code: number, sequence: number, extra = {}) => ({
    code,
    controller: 0,
    location: 4,
    sequence,
    ...extra,
  });
  const tribute = await mockPrompt(page, {
    type: "select_tribute",
    player: 0,
    cancelable: true,
    min: 2,
    max: 2,
    hint: 500,
    cards: [field(89631139, 0, { release_param: 1 }), field(46986414, 1, { release_param: 1 })],
  });
  await page.goto("/duelo/5");
  await page
    .getByRole("checkbox", { name: "Blue-Eyes White Dragon (sua zona de monstro, 1ª da esquerda)" })
    .check();
  await expect(page.getByText("Tributos: 1 de 2")).toBeVisible();
  await page
    .getByRole("checkbox", { name: "Mago Negro (sua zona de monstro, 2ª da esquerda)" })
    .check();
  await page.getByRole("button", { name: "Confirmar" }).click();
  await expect.poll(() => tribute).toEqual([{ seq: 3, response: { indexes: [0, 1] } }]);

  const sum = await mockPrompt(page, {
    type: "select_sum",
    player: 0,
    select_max: false,
    acc: 8,
    min: 0,
    max: 0,
    must: [],
    cards: [field(89631139, 0, { sum: 4 }), field(46986414, 1, { sum: 4 })],
  });
  await page.goto("/duelo/5");
  await page
    .getByRole("checkbox", { name: "Blue-Eyes White Dragon (sua zona de monstro, 1ª da esquerda)" })
    .check();
  await expect(page.getByText("Total: 4 de pelo menos 8")).toBeVisible();
  await expect(page.getByRole("button", { name: "Confirmar" })).toBeDisabled();
  await page
    .getByRole("checkbox", { name: "Mago Negro (sua zona de monstro, 2ª da esquerda)" })
    .check();
  await page.getByRole("button", { name: "Confirmar" }).click();
  await expect.poll(() => sum).toEqual([{ seq: 3, response: { indexes: [0, 1] } }]);
});

test("uma carta por vez e a ordem mandam a escolha certa", async ({ page }) => {
  const field = (code: number, sequence: number) => ({
    code,
    controller: 0,
    location: 4,
    sequence,
  });
  const unselect = await mockPrompt(page, {
    type: "select_unselect_card",
    player: 0,
    finishable: true,
    cancelable: false,
    min: 1,
    max: 2,
    selectable: [field(89631139, 0)],
    unselectable: [field(46986414, 1)],
  });
  await page.goto("/duelo/5");
  await expect(page.getByRole("button", { name: "Concluir" })).toBeVisible();
  await page
    .getByRole("radio", { name: "Mago Negro (sua zona de monstro, 2ª da esquerda)" })
    .check();
  await page.getByRole("button", { name: "Tirar" }).click();
  await expect.poll(() => unselect).toEqual([{ seq: 3, response: { index: 1 } }]);

  const deckTop = [
    { code: 46986414, controller: 0, location: 1, sequence: 0 },
    { code: 83764718, controller: 0, location: 1, sequence: 1 },
  ];
  const sort = await mockPrompt(page, { type: "sort_card", player: 0, cards: deckTop });
  await page.goto("/duelo/5");
  await page.getByRole("button", { name: "Renascer do Monstro (deck)" }).click();
  await page.getByRole("button", { name: "Mago Negro (deck)" }).click();
  await page.getByRole("button", { name: "Confirmar" }).click();
  await expect.poll(() => sort).toEqual([{ seq: 3, response: { order: [1, 0] } }]);

  const keep = await mockPrompt(page, { type: "sort_card", player: 0, cards: deckTop });
  await page.goto("/duelo/5");
  await page.getByRole("button", { name: "Deixar como está" }).click();
  await expect.poll(() => keep).toEqual([{ seq: 3, response: {} }]);
});

test("zona, marcadores, número e pedra, papel e tesoura mandam a escolha certa", async ({
  page,
}) => {
  // Livres: a zona de monstro 3 de quem escolhe (bit 2) e a de campo do oponente (bit 29).
  const zone = await mockPrompt(page, {
    type: "select_disfield",
    player: 0,
    count: 1,
    flag: 0xffffffff & ~(1 << 2) & ~(1 << 29),
  });
  await page.goto("/duelo/5");
  await expect(
    page.getByRole("button", { name: "Sua zona de monstro, 3ª da esquerda" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Zona de campo do oponente" }).click();
  await expect.poll(() => zone).toEqual([{ seq: 3, response: { places: [1, 8, 5] } }]);

  const counters = await mockPrompt(page, {
    type: "select_counter",
    player: 0,
    counter_type: 1,
    count: 2,
    cards: [
      { code: 46986414, controller: 0, location: 4, sequence: 0, counters: 2 },
      { code: 83764718, controller: 0, location: 8, sequence: 0, counters: 1 },
    ],
  });
  await page.goto("/duelo/5");
  const panel = page.getByRole("dialog", { name: "Tire 2 marcadores" });
  await panel
    .getByRole("spinbutton", { name: "Mago Negro (sua zona de monstro, 1ª da esquerda), com 2" })
    .fill("1");
  await expect(panel.getByRole("button", { name: "Confirmar" })).toBeDisabled();
  await panel
    .getByRole("spinbutton", {
      name: "Renascer do Monstro (sua zona de magia e armadilha, 1ª da esquerda), com 1",
    })
    .fill("1");
  await expect(panel.getByText("Marcadores: 2 de 2")).toBeVisible();
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
  await panel.getByRole("button", { name: "Confirmar" }).click();
  await expect.poll(() => counters).toEqual([{ seq: 3, response: { counts: [1, 1] } }]);

  const number = await mockPrompt(page, { type: "announce_number", player: 0, options: [1, 2, 3] });
  await page.goto("/duelo/5");
  await page.getByRole("button", { name: "3", exact: true }).click();
  await expect.poll(() => number).toEqual([{ seq: 3, response: { index: 2 } }]);

  const hand = await mockPrompt(page, { type: "rock_paper_scissors", player: 0 });
  await page.goto("/duelo/5");
  await page.getByRole("button", { name: "Papel", exact: true }).click();
  await expect.poll(() => hand).toEqual([{ seq: 3, response: { hand: 3 } }]);
});

test("tipo, atributo e nome de carta mandam a escolha certa", async ({ page }) => {
  const race = await mockPrompt(page, {
    type: "announce_race",
    player: 0,
    count: 1,
    available: 0x1 | 0x2000,
  });
  await page.goto("/duelo/5");
  await expect(page.getByRole("button", { name: "Guerreiro" })).toBeVisible();
  await page.getByRole("button", { name: "Dragão" }).click();
  await expect.poll(() => race).toEqual([{ seq: 3, response: { mask: 0x2000 } }]);

  const attributes = await mockPrompt(page, {
    type: "announce_attrib",
    player: 0,
    count: 2,
    available: 0x1 | 0x10 | 0x20,
  });
  await page.goto("/duelo/5");
  await page.getByRole("checkbox", { name: "TREVAS" }).check();
  await expect(page.getByRole("button", { name: "Confirmar" })).toBeDisabled();
  await page.getByRole("checkbox", { name: "LUZ" }).check();
  await page.getByRole("button", { name: "Confirmar" }).click();
  await expect.poll(() => attributes).toEqual([{ seq: 3, response: { mask: 0x30 } }]);

  const name = await mockPrompt(page, {
    type: "announce_card",
    player: 0,
    opcodes: [],
    hint: 564,
  });
  await page.goto("/duelo/5");
  const panel = page.getByRole("dialog", { name: "Declare o nome de uma carta" });
  await panel.getByLabel("Nome da carta").fill("zzz");
  await expect(panel.getByText("Nenhuma carta com esse nome.")).toBeVisible();
  await panel.getByLabel("Nome da carta").fill("mago");
  await panel.getByRole("button", { name: "Mago Negro" }).click();
  await expect.poll(() => name).toEqual([{ seq: 3, response: { code: 46986414 } }]);
});
