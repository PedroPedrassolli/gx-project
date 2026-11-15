import { expect, test, type Page } from "@playwright/test";
import { mockSession } from "./support.ts";

// Todas as páginas, do celular de 320 ao computador: nada mais largo que a tela, o menu do
// topo numa linha só, a marca e a conta sem se sobrepor e nenhum painel parado mais alto que
// a tela sem rolar (pedido do Pedro: nada de quebra de layout de um aparelho para o outro).
const WIDTHS = [320, 390, 768, 1280];

const CARDS = [
  { id: 1, code: 46986414, name: "Dark Magician", name_pt: "Mago Negro", card_type: "Monster" },
  { id: 2, code: 83764718, name: "Monster Reborn", name_pt: "Renascer do Monstro" },
  { id: 3, name: "Elemental HERO Flame Wingman", card_type: "Monster" },
];
const DETAIL = {
  ...CARDS[0],
  text: "O mago definitivo em termos de ataque e defesa. ".repeat(12),
  packs: Array.from({ length: 20 }, (_, index) => ({ id: index + 1, rarity: "common" })),
};
const PACKS = Array.from({ length: 20 }, (_, index) => ({
  id: index + 1,
  name: `Pacote com um nome bem comprido ${index + 1}`,
  position: index + 1,
  card_count: 3,
}));
const SIDE = {
  lp: 8000,
  deck: 30,
  extra: 0,
  hand: [{ code: 46986414 }, { code: 83764718 }, { hidden: true }],
  monsters: [
    { code: 46986414, face_down: false, defense: false, atk: 2500, def: 2100 },
    null,
    null,
    null,
    null,
  ],
  spells: [{ face_down: true, defense: false }, null, null, null, null],
  grave: [{ code: 83764718 }],
  banished: [],
};
const MATCH = {
  id: 5,
  status: "dueling",
  winner_team: null,
  seq: 3,
  you: 0,
  players: [
    { team: 0, nickname: "JadenYuki" },
    { team: 1, nickname: "SyrusTruesdale" },
  ],
  view: {
    you: 0,
    turn: 3,
    turn_team: 0,
    phase: "main1",
    waiting_for: 0,
    sides: [
      { ...SIDE, team: 0, extra_cards: [] },
      { ...SIDE, team: 1, hand: [{ hidden: true }, { hidden: true }] },
    ],
    events: [{ id: 1, type: "turn", team: 0 }],
    chain: [],
    prompt: {
      type: "select_idlecmd",
      player: 0,
      summonable: [{ code: 46986414, controller: 0, location: 2, sequence: 0 }],
      spsummonable: [],
      repositionable: [],
      msetable: [{ code: 46986414, controller: 0, location: 2, sequence: 0 }],
      ssetable: [{ code: 83764718, controller: 0, location: 2, sequence: 1 }],
      activatable: [],
      to_bp: true,
      to_ep: true,
    },
  },
};
const ROOM = {
  code: "ABC234",
  public: true,
  mode: "1x1",
  best_of: 1,
  banlist: true,
  destiny_draw: true,
  status: "waiting",
  owner_id: 1,
  seats: 2,
  players: [{ seat: 0, user_id: 1, nickname: "JadenYuki", ready: false, deck_chosen: false }],
};
const DECK = { id: 7, name: "Heróis", updated_at: "2026-11-14T12:00:00Z", cards: [], errors: [] };

// Uma resposta para cada rota da API que as páginas pedem.
async function mockApi(page: Page) {
  await page.route("**/api/**", (route) => {
    const path = new URL(route.request().url()).pathname;
    const data: Record<string, unknown> = {
      "/api/cards": CARDS,
      "/api/cards/1": DETAIL,
      "/api/packs": PACKS,
      "/api/decks": [{ ...DECK, counts: { main: 40, extra: 0, side: 0 } }],
      "/api/decks/7": DECK,
      "/api/rooms": [{ ...ROOM, players: 1 }],
      "/api/rooms/ABC234": ROOM,
      "/api/matches/5": MATCH,
      "/api/matches/5/replay": {
        id: 5,
        turn: 1,
        turns: 12,
        you: 0,
        players: MATCH.players,
        frames: [{ step: 0, view: { ...MATCH.view, prompt: undefined } }],
      },
    };
    if (path === "/api/session") return route.fallback();
    if (path === "/api/collection") {
      return route.fulfill({
        json: { data: [], meta: { total: { owned: 0, cards: 3, percent: 0 }, packs: [] } },
      });
    }
    if (path in data) return route.fulfill({ json: { data: data[path] } });
    return route.fulfill({ status: 503, json: { error: { status: 503, message: "Desligado." } } });
  });
}

// O que o verificador acusa numa página, já aberta na largura certa.
function problems(page: Page) {
  return page.evaluate(() => {
    const found: string[] = [];
    const root = document.documentElement;
    if (root.scrollWidth > root.clientWidth) found.push("página mais larga que a tela");
    for (const element of document.querySelectorAll<HTMLElement>("*")) {
      const style = getComputedStyle(element);
      const tall =
        style.position === "sticky" && element.getBoundingClientRect().height > innerHeight;
      if (tall && !["auto", "scroll"].includes(style.overflowY))
        found.push(`painel parado mais alto que a tela: ${element.className}`);
    }
    const rows = new Set(
      [...document.querySelectorAll(".topbar-links a")].map((link) =>
        Math.round(link.getBoundingClientRect().top),
      ),
    );
    if (rows.size > 1) found.push("menu do topo em mais de uma linha");
    const brand = document.querySelector(".topbar .brand")?.getBoundingClientRect();
    const account = document.querySelector(".topbar .account")?.getBoundingClientRect();
    if (brand && account && Math.abs(brand.top - account.top) < 8 && brand.right > account.left)
      found.push("marca e conta se sobrepõem");
    return found;
  });
}

const PAGES: [string, string, boolean][] = [
  ["/", "Início", false],
  ["/entrar", "Entrar", false],
  ["/termos", "Termos", false],
  ["/", "Início com conta", true],
  ["/cartas?carta=1", "Cartas", true],
  ["/colecao", "Coleção", true],
  ["/decks", "Decks", true],
  ["/decks/7", "Deck", true],
  ["/salas", "Salas", true],
  ["/salas/ABC234", "Sala", true],
  ["/duelo/5", "Duelo", true],
  ["/duelo/5/replay", "Replay", true],
];

for (const [path, name, loggedIn] of PAGES) {
  test(`${name} fica inteira em todas as larguras`, async ({ page }) => {
    await mockSession(page, { loggedIn });
    await mockApi(page);
    for (const width of WIDTHS) {
      await page.setViewportSize({ width, height: 800 });
      await page.goto(path);
      await expect(page.locator("main h1").first()).toBeAttached();
      await page.waitForLoadState("networkidle");
      expect(await problems(page), `${name} em ${width}px`).toEqual([]);
    }
  });
}
