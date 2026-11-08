import { test } from "node:test";
import assert from "node:assert/strict";
import type { CardSummary } from "../catalog/cards.ts";
import { deckErrors, editDeck, sectionCount, type DeckRow } from "./deck.ts";

// Cartas 1 a 21 são monstros comuns; 100 é de Fusão; 50 está proibida e 51 é limitada.
const cards = new Map<number, CardSummary>(
  [
    ...Array.from({ length: 21 }, (_, i) => ({
      id: i + 1,
      name: `Monstro ${i + 1}`,
      monster_types: ["Normal"],
    })),
    { id: 100, name: "Herói de Fusão", monster_types: ["Fusion", "Effect"] },
    { id: 50, name: "Pote", banlist: "forbidden" as const },
    { id: 51, name: "Raio", banlist: "limited" as const },
  ].map((card) => [card.id, card]),
);
const owned = new Map([...cards.keys()].map((id) => [id, 3]));
const row = (card_id: number, section: DeckRow["section"], quantity: number, destiny = false) => ({
  card_id,
  section,
  quantity,
  destiny,
});
const mainDeck = (copies = 2) => Array.from({ length: 20 }, (_, i) => row(i + 1, "main", copies));
const errors = (rows: DeckRow[], have = owned) => deckErrors(rows, cards, have, "en");

test("deck de 40 no Main, sem Extra nem Side, é válido", () => {
  assert.deepEqual(errors(mainDeck()), []);
  assert.equal(sectionCount(mainDeck(), "main"), 40);
});

test("avisa o tamanho errado de cada seção", () => {
  const side = Array.from({ length: 16 }, (_, i) => row(i + 1, "side", 1));

  assert.deepEqual(errors([...mainDeck().slice(1), ...side]), [
    "O Main Deck precisa ter de 40 a 60 cartas (tem 38).",
    "O Side Deck pode ter até 15 cartas (tem 16).",
  ]);
});

test("as mesmas regras do backend, com as mesmas mensagens", () => {
  const rows = [
    ...mainDeck().slice(1),
    row(1, "main", 3),
    row(1, "side", 1),
    row(50, "side", 1),
    row(51, "side", 2),
    row(100, "main", 1),
    row(2, "extra", 1),
    row(3, "side", 1, true),
  ];
  const have = new Map(owned).set(1, 4).set(3, 2);

  assert.deepEqual(errors(rows, have), [
    "Herói de Fusão é de Fusão ou Sincro: vai no Extra Deck.",
    "Monstro 1: no máximo 3 cópias somando Main, Extra e Side (tem 4).",
    "Monstro 2 não é de Fusão nem Sincro: não vai no Extra Deck.",
    "Monstro 3: você tem 2 e o deck usa 3.",
    "Monstro 3 só pode ser Destiny no Main Deck.",
    "Pote está proibida.",
    "Raio é limitada: no máximo 1 cópia (tem 2).",
  ]);
});

test("adicionar soma na linha da seção e para em 3 cópias da carta no deck todo", () => {
  let rows: DeckRow[] = [];
  rows = editDeck(rows, { type: "add", cardId: 1, section: "main" });
  rows = editDeck(rows, { type: "add", cardId: 1, section: "main" });
  rows = editDeck(rows, { type: "add", cardId: 1, section: "side" });
  rows = editDeck(rows, { type: "add", cardId: 1, section: "side" });

  assert.deepEqual(rows, [row(1, "main", 2), row(1, "side", 1)]);
});

test("tirar diminui e apaga a linha que chega a zero", () => {
  const rows = editDeck([row(1, "main", 2), row(2, "main", 1)], {
    type: "remove",
    cardId: 2,
    section: "main",
  });

  assert.deepEqual(editDeck(rows, { type: "remove", cardId: 1, section: "main" }), [
    row(1, "main", 1),
  ]);
});

test("marca e desmarca a Destiny da carta no Main", () => {
  const rows = editDeck([row(1, "main", 2)], { type: "destiny", cardId: 1 });

  assert.deepEqual(rows, [row(1, "main", 2, true)]);
  assert.deepEqual(editDeck(rows, { type: "destiny", cardId: 1 }), [row(1, "main", 2)]);
});

test("mover passa uma cópia para outra seção", () => {
  const rows = editDeck([row(1, "main", 2, true)], {
    type: "move",
    cardId: 1,
    from: "main",
    to: "side",
  });

  assert.deepEqual(rows, [row(1, "main", 1, true), row(1, "side", 1)]);
});
