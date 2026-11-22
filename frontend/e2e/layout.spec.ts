import { expect, test, type Page } from "@playwright/test";
import { mockSession } from "./support.ts";

// Todas as páginas, do celular de 320 ao computador: nada mais largo que a tela, o menu do
// topo numa linha só, a marca e a conta sem se sobrepor e nenhum painel parado mais alto que
// a tela sem rolar (pedido do Pedro: nada de quebra de layout de um aparelho para o outro).
const WIDTHS = [320, 390, 768, 1024, 1280];

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
  cover: 1,
}));
// A loja: um pacote liberado, sem DP para comprar 10, e um bloqueado com a barra.
const SHOP = {
  balance: 120,
  level: 3,
  packs: PACKS.slice(0, 4).map((pack, index) => ({
    id: pack.id,
    name: pack.name,
    price: 50,
    cards_per_pack: 5,
    available: index % 2 === 0,
    hint:
      index % 2 === 0
        ? null
        : "Tenha 50% das cartas de Pacote com um nome bem comprido 1 (você tem 12%).",
    progress: index % 2 === 0 ? null : 24,
    new: index === 0,
  })),
};
// Os três jeitos de um personagem aparecer, com nome e descrição longos.
const CHARACTERS = (["beaten", "unlocked", "locked"] as const).map((status, index) => ({
  id: `personagem-${index}`,
  position: index + 1,
  name: "Dr. Vellian Crowler",
  description: "O professor. Engrenagens antigas e monstros enormes que esmagam qualquer defesa.",
  group: {
    id: index < 2 ? "alunos" : "lendas",
    name: index < 2 ? "Alunos da Academia" : "Lendas de Duel Monsters",
  },
  deck: "Medieval Ages",
  bonus: 840,
  wins: status === "beaten" ? 12 : 0,
  status,
  unlock_hint: status === "locked" ? "Vença Dr. Vellian Crowler para liberar." : undefined,
  signature: { id: 1, name: "Ancient Gear Golem", image: 83104731 },
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
  banlist: true,
  destiny_draw: true,
  decision_seconds: 90,
  duel_minutes: 60,
  status: "waiting",
  owner_id: 1,
  seats: 2,
  players: [{ seat: 0, user_id: 1, nickname: "JadenYuki", ready: false, deck_chosen: false }],
};
// O deck com cartas no Main e no Extra: a grade, os botões e o Destiny em toda largura.
const DECK = {
  id: 7,
  name: "Heróis",
  updated_at: "2026-11-14T12:00:00Z",
  cards: [
    { card_id: 1, section: "main", quantity: 3, destiny: true },
    { card_id: 2, section: "main", quantity: 1, destiny: false },
    { card_id: 3, section: "extra", quantity: 1, destiny: false },
  ],
  errors: [],
};

// Uma resposta para cada rota da API que as páginas pedem.
async function mockApi(page: Page) {
  await page.route("**/api/**", (route) => {
    const path = new URL(route.request().url()).pathname;
    const data: Record<string, unknown> = {
      "/api/cards": CARDS,
      "/api/cards/1": DETAIL,
      "/api/packs": PACKS,
      "/api/decks": [{ ...DECK, counts: { main: 40, extra: 0 } }],
      "/api/decks/7": DECK,
      "/api/shop": SHOP,
      "/api/shop/converter": { min: 10, max: 99, cards: [{ card_id: 1, quantity: 12 }] },
      "/api/rooms": [{ ...ROOM, players: 1 }],
      "/api/rooms/ABC234": ROOM,
      "/api/matches/5": MATCH,
      "/api/characters": { characters: CHARACTERS },
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
      [...document.querySelectorAll(".mainnav a")].map((link) =>
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
  ["/jogar", "Jogar", true],
  ["/cartas?carta=1", "Cartas", true],
  ["/colecao", "Coleção", true],
  ["/decks", "Decks", true],
  ["/decks/7", "Deck", true],
  ["/loja", "Loja", true],
  ["/loja/conversor", "Conversor", true],
  ["/salas", "Salas", true],
  ["/salas/ABC234", "Sala", true],
  ["/personagens", "Personagens", true],
  ["/personagens?duelar=personagem-1", "Personagens com o deck", true],
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
