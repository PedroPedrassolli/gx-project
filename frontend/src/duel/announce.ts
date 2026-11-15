import { displayName, plain, type CardSummary, type Language } from "../catalog/cards.ts";
import { ATTRIBUTES, RACES } from "../catalog/labels.ts";
import type { Prompt } from "./api.ts";
import { zoneName } from "./zones.ts";

// O que os anúncios da engine precisam: as zonas livres, os bits de tipo e de atributo e a
// busca do nome de uma carta.

export type Zone = { player: number; location: number; sequence: number; label: string };

const MZONE = 0x04;
const SZONE = 0x08;

// O mesmo nome que a zona tem nas escolhas de carta (zones.ts), com letra maiúscula.
function zoneLabel(location: number, sequence: number, mine: boolean) {
  const name = zoneName(location, sequence, mine);
  return `${name[0]?.toUpperCase()}${name.slice(1)}`;
}

// No "flag", bit ligado é zona que não vale. Do lado de quem escolhe: monstros nos bits 0 a
// 4, magias e armadilhas de 8 a 12 e o campo no 13; do outro lado, 16 bits acima.
export function freeZones(prompt: Prompt): Zone[] {
  const flag = Number(prompt.flag);
  const zones: Zone[] = [];
  for (const side of [0, 1]) {
    const player = side === 0 ? prompt.player : 1 - prompt.player;
    const groups: [number, number, number][] = [
      [MZONE, 0, 5],
      [SZONE, 8, 6],
    ];
    for (const [location, firstBit, size] of groups) {
      for (let sequence = 0; sequence < size; sequence++) {
        if ((flag & (1 << (firstBit + sequence + 16 * side))) === 0)
          zones.push({
            player,
            location,
            sequence,
            label: zoneLabel(location, sequence, side === 0),
          });
      }
    }
  }
  return zones;
}

// Bits de tipo (RACE_* do constant.lua) com o nome em inglês do catálogo. Os quatro últimos
// não existem no jogo de referência, mas a engine pode oferecer.
const RACE_BITS: [number, string][] = [
  [0x1, "Warrior"],
  [0x2, "Spellcaster"],
  [0x4, "Fairy"],
  [0x8, "Fiend"],
  [0x10, "Zombie"],
  [0x20, "Machine"],
  [0x40, "Aqua"],
  [0x80, "Pyro"],
  [0x100, "Rock"],
  [0x200, "Winged Beast"],
  [0x400, "Plant"],
  [0x800, "Insect"],
  [0x1000, "Thunder"],
  [0x2000, "Dragon"],
  [0x4000, "Beast"],
  [0x8000, "Beast-Warrior"],
  [0x10000, "Dinosaur"],
  [0x20000, "Fish"],
  [0x40000, "Sea Serpent"],
  [0x80000, "Reptile"],
  [0x100000, "Psychic"],
  [0x200000, "Divine-Beast"],
  [0x400000, "Creator God"],
  [0x800000, "Wyrm"],
  [0x1000000, "Cyberse"],
  [0x2000000, "Illusion"],
];
const OTHER_RACES: Record<string, string> = {
  "Creator God": "Deus Criador",
  Wyrm: "Wyrm",
  Cyberse: "Ciberso",
  Illusion: "Ilusão",
};

// Bits de atributo (ATTRIBUTE_* do constant.lua).
const ATTRIBUTE_BITS: [number, string][] = [
  [0x1, "EARTH"],
  [0x2, "WATER"],
  [0x4, "FIRE"],
  [0x8, "WIND"],
  [0x10, "LIGHT"],
  [0x20, "DARK"],
  [0x40, "DIVINE"],
];

export type Option = { bit: number; label: string };

// Só os bits que a engine deixa declarar ("available").
export function announceOptions(prompt: Prompt): Option[] {
  const available = Number(prompt.available);
  const race = prompt.type === "announce_race";
  const labels: Record<string, string> = race ? { ...RACES, ...OTHER_RACES } : ATTRIBUTES;
  return (race ? RACE_BITS : ATTRIBUTE_BITS)
    .filter(([bit]) => (available & bit) !== 0)
    .map(([bit, name]) => ({ bit, label: labels[name] ?? name }));
}

// Busca para declarar um nome: sem acento e sem caixa, no nome em português e no inglês.
// Primeiro o nome (no idioma escolhido) que começa com o que foi digitado.
export function searchCards(
  cards: Iterable<CardSummary>,
  query: string,
  language: Language,
  limit = 8,
) {
  const wanted = plain(query.trim());
  if (wanted.length < 2) return [];
  const found = [...cards].filter(
    (card) =>
      card.code !== undefined &&
      [card.name, card.name_pt ?? ""].some((name) => plain(name).includes(wanted)),
  );
  const starts = (card: CardSummary) =>
    plain(displayName(card, language)).startsWith(wanted) ? 0 : 1;
  return found
    .sort(
      (a, b) =>
        starts(a) - starts(b) ||
        displayName(a, language).localeCompare(displayName(b, language), "pt"),
    )
    .slice(0, limit);
}
