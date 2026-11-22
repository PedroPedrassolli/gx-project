import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mockSession, PLAYER } from "./support.ts";

type Room = {
  code: string;
  public: boolean;
  mode: string;
  banlist: boolean;
  destiny_draw: boolean;
  decision_seconds: number | null;
  duel_minutes: number | null;
  status: string;
  owner_id: number;
  seats: number;
  players: Record<string, unknown>[];
  match_id?: number;
  opening?: Record<string, unknown>;
};

const ME = { seat: 0, user_id: PLAYER.id, nickname: "JadenYuki", ready: false, deck_chosen: false };
const ROOM: Room = {
  code: "ABC234",
  public: true,
  mode: "1x1",
  banlist: true,
  destiny_draw: true,
  decision_seconds: 90,
  duel_minutes: 60,
  status: "waiting",
  owner_id: PLAYER.id,
  seats: 2,
  players: [ME],
};
const DECKS = [
  {
    id: 7,
    name: "Heróis",
    updated_at: "2026-11-14T12:00:00Z",
    counts: { main: 40, extra: 0 },
  },
  {
    id: 8,
    name: "Vazio",
    updated_at: "2026-11-14T12:00:00Z",
    counts: { main: 3, extra: 0 },
  },
  {
    id: 9,
    name: "Proibidas",
    updated_at: "2026-11-14T12:00:00Z",
    counts: { main: 40, extra: 0 },
  },
];

// API falsa das salas, sem tempo real (o token responde 503): a tela consulta a sala.
async function mockRoom(page: Page, room: Room = ROOM) {
  let current: Room = structuredClone(room);
  await page.route("**/api/realtime/token", (route) =>
    route.fulfill({
      status: 503,
      json: { error: { status: 503, message: "O tempo real está desligado." } },
    }),
  );
  await page.route("**/api/decks", (route) => route.fulfill({ json: { data: DECKS } }));
  await page.route("**/api/rooms/ABC234", (route) => route.fulfill({ json: { data: current } }));
  await page.route("**/api/rooms/ABC234/join", (route) => {
    current = { ...current, players: [...current.players, { ...ME, seat: 1 }] };
    return route.fulfill({ json: { data: current } });
  });
  await page.route("**/api/rooms/ABC234/ready", (route) => {
    const body = route.request().postDataJSON();
    if (body.deck_id === "9") {
      return route.fulfill({
        status: 422,
        json: {
          error: {
            status: 422,
            message: "Este deck não vale nesta sala.",
            fields: { deck: ["Pot of Greed está proibida."] },
          },
        },
      });
    }
    current = {
      ...current,
      players: [{ ...ME, ready: body.ready, deck_chosen: true, deck_id: Number(body.deck_id) }],
    };
    return route.fulfill({ json: { data: current } });
  });
  await page.route("**/api/rooms/ABC234/leave", (route) => route.fulfill({ status: 204 }));
  return { set: (next: Room) => (current = next) };
}

test.beforeEach(async ({ page }) => mockSession(page, { loggedIn: true }));

test("mostra os lugares e as opções, e fica pronto com um deck", async ({ page }) => {
  await mockRoom(page);
  // Enquanto a sala espera, o catálogo do duelo já vem.
  const catalog = page.waitForRequest("**/api/cards");
  await page.route("**/api/cards", (route) => route.fulfill({ json: { data: [] } }));
  await page.route("**/api/packs", (route) => route.fulfill({ json: { data: [] } }));
  await page.goto("/salas/abc234");
  await catalog;

  await expect(page.getByRole("heading", { level: 1, name: "Sala ABC234" })).toBeVisible();
  const seats = page.getByRole("list", { name: "Lugares" });
  await expect(seats.getByRole("listitem").first()).toContainText("JadenYuki");
  await expect(seats.getByRole("listitem").first()).toContainText("Criou a sala");
  await expect(seats.getByRole("listitem").nth(1)).toHaveText("Vaga livre");
  await expect(page.getByText("Banlist do jogo")).toBeVisible();
  await expect(page.getByText("1 min 30 s por resposta")).toBeVisible();
  await expect(page.getByText("Duelo de 60 min")).toBeVisible();
  await expect(page.getByRole("status").filter({ hasText: "a cada 2 segundos" })).toBeVisible();

  await page.getByLabel("Deck", { exact: true }).selectOption("Heróis");
  await page.getByRole("button", { name: "Estou pronto" }).click();
  await expect(seats.getByRole("listitem").first()).toContainText("Pronto");
  await expect(page.getByRole("button", { name: "Não estou pronto" })).toBeVisible();

  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);
});

test("sem deck ou com deck incompleto, 'Estou pronto' desativa e diz o que falta", async ({
  page,
}) => {
  await mockRoom(page);
  await page.goto("/salas/ABC234");
  const ready = page.getByRole("button", { name: "Estou pronto" });
  await expect(ready).toBeDisabled();
  await expect(page.getByText("Escolha um deck para ficar pronto.")).toBeVisible();

  await page.getByLabel("Deck", { exact: true }).selectOption("Vazio");
  await expect(ready).toBeDisabled();
  await expect(page.getByText("O Main Deck tem 3 cartas: precisa ter de 40 a 60.")).toBeVisible();
});

test("deck que o servidor recusa na sala mostra o que falta", async ({ page }) => {
  await mockRoom(page);
  await page.goto("/salas/ABC234");
  await page.getByLabel("Deck", { exact: true }).selectOption("Proibidas");
  await page.getByRole("button", { name: "Estou pronto" }).click();

  const alert = page.getByRole("alert");
  await expect(alert).toContainText("Este deck não vale nesta sala.");
  await expect(alert).toContainText("Pot of Greed está proibida.");
});

test("sala cheia: quem chega pelo link não tem como entrar, e a sala diz por quê", async ({
  page,
}) => {
  await mockRoom(page, {
    ...ROOM,
    owner_id: 2,
    players: [
      { ...ME, user_id: 2, nickname: "Syrus" },
      { ...ME, seat: 1, user_id: 3, nickname: "Chumley" },
    ],
  });
  await page.goto("/salas/ABC234");

  await expect(page.getByRole("button", { name: "Entrar na sala" })).toBeDisabled();
  await expect(page.getByText("A sala está cheia.")).toBeVisible();
});

test("sem tempo real, quem chega aparece na próxima consulta", async ({ page }) => {
  const room = await mockRoom(page);
  await page.goto("/salas/ABC234");
  await expect(page.getByText("Vaga livre")).toBeVisible();

  room.set({
    ...ROOM,
    players: [ME, { seat: 1, user_id: 2, nickname: "Syrus", ready: true, deck_chosen: true }],
  });
  const seats = page.getByRole("list", { name: "Lugares" });
  await expect(seats.getByRole("listitem").nth(1)).toContainText("Syrus", { timeout: 5000 });
  await expect(seats.getByRole("listitem").nth(1)).toContainText("Pronto");
  await expect(seats.getByRole("button", { name: "Tirar da sala" })).toBeVisible();
});

test("quem abre o link de uma sala entra nela", async ({ page }) => {
  await mockRoom(page, {
    ...ROOM,
    owner_id: 2,
    players: [{ ...ME, user_id: 2, nickname: "Syrus" }],
  });
  await page.goto("/salas/ABC234");
  await page.getByRole("button", { name: "Entrar na sala" }).click();

  await expect(page.getByRole("heading", { name: "Seu deck" })).toBeVisible();
  await page.getByRole("button", { name: "Sair da sala" }).click();
  await expect(page).toHaveURL("/salas");
});

test("sala que não existe avisa", async ({ page }) => {
  await mockRoom(page);
  await page.route("**/api/rooms/ZZZ999", (route) =>
    route.fulfill({ status: 404, json: { error: { status: 404, message: "Não encontrado." } } }),
  );
  await page.goto("/salas/ZZZ999");

  await expect(page.getByRole("alert")).toHaveText(
    "Não achamos esta sala. Confira o código ou crie outra.",
  );
});

test("cria a sala com as opções escolhidas e abre a sala de espera", async ({ page }) => {
  await mockRoom(page);
  let sent: unknown;
  await page.route("**/api/rooms", (route) => {
    if (route.request().method() !== "POST") return route.fulfill({ json: { data: [] } });
    sent = route.request().postDataJSON();
    return route.fulfill({ status: 201, json: { data: ROOM } });
  });
  await page.goto("/salas");
  await expect(page.getByText("Nenhuma sala aberta agora.")).toBeVisible();

  await page.getByLabel("Destiny Draw").uncheck();
  await page.getByLabel("Tempo de resposta").selectOption("30 s");
  await page.getByLabel("Tempo do duelo").selectOption("Sem limite");
  await page.getByRole("button", { name: "Criar sala" }).click();
  await expect(page).toHaveURL("/salas/ABC234");
  expect(sent).toEqual({
    public: true,
    banlist: true,
    destiny_draw: false,
    decision_seconds: 30,
    duel_minutes: null,
  });
});

test("lista as salas abertas e vai para uma pelo código", async ({ page }) => {
  await mockRoom(page);
  await page.route("**/api/rooms", (route) =>
    route.fulfill({
      json: {
        data: [
          {
            code: "ABC234",
            owner: "Syrus",
            players: 1,
            seats: 2,
            banlist: true,
            destiny_draw: true,
            decision_seconds: null,
            duel_minutes: 40,
          },
        ],
      },
    }),
  );
  await page.goto("/salas");
  await expect(page.getByRole("link", { name: "Sala de Syrus" })).toHaveAttribute(
    "href",
    "/salas/ABC234",
  );
  await expect(page.getByText("Resposta sem limite")).toBeVisible();
  await expect(page.getByText("Duelo de 40 min")).toBeVisible();
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);

  await page.getByLabel("Código da sala").fill("abc234");
  await page.getByRole("button", { name: "Ir para a sala" }).click();
  await expect(page).toHaveURL("/salas/ABC234");
});

// Os dois prontos: o Jaden (lugar 0) e o Syrus (lugar 1).
const READY = { ...ME, ready: true, deck_chosen: true, deck_id: 7 };
const SYRUS = { seat: 1, user_id: 2, nickname: "Syrus", ready: true, deck_chosen: true };
const NO_HANDS = { hand: null, chosen: [], last: null, chooser_seat: null };

test("com os dois prontos, o pedra, papel e tesoura decide quem começa", async ({ page }) => {
  const room = await mockRoom(page, { ...ROOM, players: [READY, SYRUS], opening: NO_HANDS });
  const sent: unknown[] = [];
  await page.route("**/api/rooms/ABC234/hand", (route) => {
    sent.push(route.request().postDataJSON());
    // Empate na primeira rodada; na segunda, o papel do Jaden ganha da pedra do Syrus.
    const last = sent.length === 1 ? { "0": "rock", "1": "rock" } : { "0": "paper", "1": "rock" };
    const opening = { ...NO_HANDS, last, chooser_seat: sent.length === 1 ? null : 0 };
    return route.fulfill({
      json: { data: room.set({ ...ROOM, players: [READY, SYRUS], opening }) },
    });
  });
  await page.route("**/api/rooms/ABC234/first", (route) => {
    sent.push(route.request().postDataJSON());
    const data = { ...ROOM, status: "dueling", match_id: 5, players: [READY, SYRUS] };
    return route.fulfill({ json: { data: room.set(data) } });
  });
  await page.goto("/salas/ABC234");

  const hands = page.getByRole("group", { name: "Sua mão" });
  await hands.getByRole("button", { name: "Pedra" }).click();
  await expect(page.getByText("Empate: os dois tiraram pedra. De novo!")).toBeVisible();
  await hands.getByRole("button", { name: "Papel" }).click();
  await expect(page.getByText("Você tirou papel e Syrus, pedra: você ganhou.")).toBeVisible();
  const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
  expect(results.violations).toEqual([]);

  await page.getByRole("button", { name: "Deixar Syrus começar" }).click();
  await expect(page).toHaveURL("/duelo/5");
  expect(sent).toEqual([{ hand: "rock" }, { hand: "paper" }, { first: false }]);
});

test("quem escolheu a mão espera o outro, e quem perdeu espera a escolha", async ({ page }) => {
  const room = await mockRoom(page, {
    ...ROOM,
    players: [READY, SYRUS],
    opening: { ...NO_HANDS, chosen: [1] },
  });
  await page.goto("/salas/ABC234");
  await expect(page.getByText("Syrus já escolheu. E você?")).toBeVisible();

  room.set({
    ...ROOM,
    players: [READY, SYRUS],
    opening: { ...NO_HANDS, hand: "rock", chosen: [0] },
  });
  await expect(
    page.getByRole("status").filter({ hasText: "Você tirou pedra. Esperando Syrus…" }),
  ).toBeVisible();

  const opening = { ...NO_HANDS, last: { "0": "rock", "1": "paper" }, chooser_seat: 1 };
  room.set({ ...ROOM, players: [READY, SYRUS], opening });
  await expect(page.getByText("Você tirou pedra e Syrus, papel: Syrus ganhou.")).toBeVisible();
  await expect(
    page.getByRole("status").filter({ hasText: "Syrus está escolhendo quem começa…" }),
  ).toBeVisible();
});
