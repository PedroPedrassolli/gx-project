import { CARD_TYPES, MONSTER_TYPES, PROPERTIES, RACES, label } from "./labels.ts";

// Cartas do catálogo como a API manda (/api/cards, ADR 0007) e os filtros da tela, que
// rodam aqui mesmo: a lista inteira vem numa resposta só, guardada na CDN.

export type CardSummary = {
  id: number;
  name: string;
  name_pt?: string;
  card_type?: "Monster" | "Spell" | "Trap";
  property?: string;
  attribute?: string;
  race?: string;
  monster_types?: string[];
  level?: number;
  atk?: number;
  def?: number;
  banlist?: "forbidden" | "limited" | "semi_limited";
  rarity?: string;
  image?: number; // código da imagem; sem ele (carta só do anime), a carta fica só com o texto
};

export type CardDetail = CardSummary & {
  passcode?: number;
  name_in_game?: string;
  text?: string;
  text_pt?: string;
  packs?: { id: number; rarity: string }[];
  source: string;
};

export type Pack = { id: number; name: string; position: number; card_count: number };

export type Language = "pt" | "en";
export type SortKey = "name" | "atk" | "def" | "level" | "type";

export type Filters = {
  q: string;
  cardType: string;
  attribute: string;
  race: string;
  monsterType: string;
  level: string;
  atkMin: string;
  atkMax: string;
  defMin: string;
  defMax: string;
  sort: SortKey;
  order: "asc" | "desc";
};

export const EMPTY_FILTERS: Filters = {
  q: "",
  cardType: "",
  attribute: "",
  race: "",
  monsterType: "",
  level: "",
  atkMin: "",
  atkMax: "",
  defMin: "",
  defMax: "",
  sort: "name",
  order: "asc",
};

// Imagens das cartas no Cloudflare Pages (ADR 0004), em WebP com 3 larguras: p (112) na
// lista, m (268) e g (813, a da imagem original) no detalhe.
export const IMAGES = "https://gx-project-imagens.pages.dev/cards";
export const IMAGE_WIDTHS = { p: 112, m: 268, g: 813 };

export function imageUrl(code: number, size: keyof typeof IMAGE_WIDTHS): string {
  return `${IMAGES}/${size}/${code}.webp`;
}

// Nome na língua escolhida; sem tradução, o nome em inglês.
export function displayName(card: CardSummary, language: Language): string {
  return language === "pt" ? (card.name_pt ?? card.name) : card.name;
}

// Sem acento e sem caixa: "Dragão" e "dragao" são iguais na busca.
export function plain(text: string): string {
  return text
    .normalize("NFD")
    .replace(/\p{Mn}/gu, "")
    .toLowerCase();
}

function inRange(value: number | undefined, min: string, max: string): boolean {
  if (min === "" && max === "") return true;
  if (value === undefined) return false; // ATK ou DEF "?"
  return value >= (min === "" ? 0 : Number(min)) && value <= (max === "" ? Infinity : Number(max));
}

export function matches(card: CardSummary, filters: Filters): boolean {
  const query = plain(filters.q.trim());
  return (
    (query === "" || [card.name, card.name_pt ?? ""].some((name) => plain(name).includes(query))) &&
    (filters.cardType === "" || card.card_type === filters.cardType) &&
    (filters.attribute === "" || card.attribute === filters.attribute) &&
    (filters.race === "" || card.race === filters.race) &&
    (filters.monsterType === "" || (card.monster_types ?? []).includes(filters.monsterType)) &&
    (filters.level === "" || card.level === Number(filters.level)) &&
    inRange(card.atk, filters.atkMin, filters.atkMax) &&
    inRange(card.def, filters.defMin, filters.defMax)
  );
}

const SORT_VALUE: Record<
  Exclude<SortKey, "name">,
  (card: CardSummary) => number | string | undefined
> = {
  atk: (card) => card.atk,
  def: (card) => card.def,
  level: (card) => card.level,
  type: (card) => card.card_type,
};

// Ordena pelo campo pedido e desempata pelo nome exibido; quem não tem o valor (magia sem
// nível, ATK "?") vai para o fim.
export function sortCards(
  cards: CardSummary[],
  filters: Filters,
  language: Language,
): CardSummary[] {
  const byName = (a: CardSummary, b: CardSummary) =>
    displayName(a, language).localeCompare(displayName(b, language), "pt-BR");
  const direction = filters.order === "desc" ? -1 : 1;
  if (filters.sort === "name") return [...cards].sort((a, b) => byName(a, b) * direction);

  const value = SORT_VALUE[filters.sort];
  return [...cards].sort((a, b) => {
    const [first, second] = [value(a), value(b)];
    if (first === undefined || second === undefined) {
      return first === second ? byName(a, b) : first === undefined ? 1 : -1;
    }
    return (first < second ? -1 : first > second ? 1 : 0) * direction || byName(a, b);
  });
}

// Cor da moldura pela espécie de carta (só aparência).
export function frame(card: CardSummary): string {
  if (card.card_type === "Spell") return "spell";
  if (card.card_type === "Trap") return "trap";
  const types = card.monster_types ?? [];
  return (
    ["Fusion", "Ritual", "Synchro", "Normal"].find((type) => types.includes(type))?.toLowerCase() ??
    "effect"
  );
}

// Linha de tipo da carta: "Dragão / Sincro / Efeito" ou "Magia de Campo".
export function typeLine(card: CardSummary): string {
  if (card.card_type !== "Monster") {
    return `${label(CARD_TYPES, card.card_type)} ${label(PROPERTIES, card.property)}`.trim();
  }
  const types = (card.monster_types ?? []).map((type) => label(MONSTER_TYPES, type));
  return [label(RACES, card.race), ...types].join(" / ");
}
