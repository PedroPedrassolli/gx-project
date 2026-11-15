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
  return { set: (next: unknown) => (current = next as typeof STATE) };
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

test("na fase principal, a escolha vai para o servidor e a mesa nova aparece", async ({ page }) => {
  const sent = await mockPrompt(page, IDLE);
  await page.goto("/duelo/5");

  const panel = page.getByRole("region", { name: "Fase principal: o que fazer?" });
  await expect(
    panel.getByRole("button", { name: "Ativar Renascer do Monstro (mão)" }),
  ).toContainText("Special Summon 1 monster");
  await expect(panel.getByRole("button", { name: "Encerrar o turno" })).toBeVisible();
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);

  await panel.getByRole("button", { name: "Invocar Mago Negro (mão)" }).click();
  await expect(page.getByRole("status").filter({ hasText: "Vez de Syrus" })).toBeVisible();
  await expect.poll(() => sent).toEqual([{ seq: 3, response: { command: "summon", index: 0 } }]);
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
    .getByRole("region", { name: "Usar o Destiny Draw?" })
    .getByRole("button", { name: "Sim" })
    .click();
  await expect.poll(() => yesNo).toEqual([{ seq: 3, response: { yes: true } }]);

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

test("escolher cartas: um toque basta para uma carta; várias pedem o Confirmar", async ({
  page,
}) => {
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
  const attack = page.getByRole("region", { name: "Escolha o alvo do ataque" });
  await expect(attack.getByRole("button", { name: "Cancelar" })).toBeVisible();
  await attack.getByRole("button", { name: "Blue-Eyes White Dragon (campo do oponente)" }).click();
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
  const panel = page.getByRole("region", { name: "Escolha a carta para destruir" });
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
  await page.getByRole("checkbox", { name: "Blue-Eyes White Dragon (campo)" }).check();
  await expect(page.getByText("Tributos: 1 de 2")).toBeVisible();
  await page.getByRole("checkbox", { name: "Mago Negro (campo)" }).check();
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
  await page.getByRole("checkbox", { name: "Blue-Eyes White Dragon (campo)" }).check();
  await expect(page.getByText("Total: 4 de pelo menos 8")).toBeVisible();
  await expect(page.getByRole("button", { name: "Confirmar" })).toBeDisabled();
  await page.getByRole("checkbox", { name: "Mago Negro (campo)" }).check();
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
  await page.getByRole("button", { name: "Tirar Mago Negro (campo)" }).click();
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
  await expect(page.getByRole("button", { name: "Sua zona de monstro 3" })).toBeVisible();
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
  const panel = page.getByRole("region", { name: "Tire 2 marcadores" });
  await panel.getByRole("spinbutton", { name: "Mago Negro (campo), com 2" }).fill("1");
  await expect(panel.getByRole("button", { name: "Confirmar" })).toBeDisabled();
  await panel.getByRole("spinbutton", { name: "Renascer do Monstro (campo), com 1" }).fill("1");
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
  await page.getByRole("button", { name: "Papel" }).click();
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
  const panel = page.getByRole("region", { name: "Declare o nome de uma carta" });
  await panel.getByLabel("Nome da carta").fill("zzz");
  await expect(panel.getByText("Nenhuma carta com esse nome.")).toBeVisible();
  await panel.getByLabel("Nome da carta").fill("mago");
  await panel.getByRole("button", { name: "Mago Negro" }).click();
  await expect.poll(() => name).toEqual([{ seq: 3, response: { code: 46986414 } }]);
});
