import { test } from "node:test";
import assert from "node:assert/strict";
import type { CardSummary } from "../catalog/cards.ts";
import {
  addBlocked,
  deckErrors,
  deckOrder,
  deckSizeProblem,
  editDeck,
  sectionCount,
  typeCounts,
  type DeckRow,
} from "./deck.ts";

// Cartas 1 a 21 são monstros comuns; 100 a 105 são de Fusão; 50 está proibida e 51 é limitada.
const cards = new Map<number, CardSummary>(
  [
    ...Array.from({ length: 21 }, (_, i) => ({
      id: i + 1,
      name: `Monstro ${i + 1}`,
      monster_types: ["Normal"],
    })),
    { id: 100, name: "Herói de Fusão", monster_types: ["Fusion", "Effect"] },
    ...Array.from({ length: 5 }, (_, i) => ({
      id: 101 + i,
      name: `Fusão ${i + 2}`,
      monster_types: ["Fusion"],
    })),
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

test("deck de 40 no Main, sem Extra, é válido", () => {
  assert.deepEqual(errors(mainDeck()), []);
  assert.equal(sectionCount(mainDeck(), "main"), 40);
});

test("avisa o tamanho errado de cada seção", () => {
  // 16 no Extra: cinco Fusões com 3 cópias e mais uma.
  const extra = [
    ...Array.from({ length: 5 }, (_, i) => row(100 + i, "extra", 3)),
    row(105, "extra", 1),
  ];

  assert.deepEqual(errors([...mainDeck().slice(1), ...extra]), [
    "O Main Deck precisa ter de 40 a 60 cartas (tem 38).",
    "O Extra Deck pode ter até 15 cartas (tem 16).",
  ]);
});

test("as mesmas regras do backend, com as mesmas mensagens", () => {
  const rows = [
    ...mainDeck().slice(1),
    row(1, "main", 4),
    row(50, "main", 1),
    row(51, "main", 2),
    row(100, "main", 1),
    row(100, "extra", 1, true),
    row(2, "extra", 1),
  ];
  const have = new Map(owned).set(1, 4).set(3, 1);

  assert.deepEqual(errors(rows, have), [
    "Herói de Fusão é de Fusão ou Sincro: vai no Extra Deck.",
    "Herói de Fusão só pode ser Destiny no Main Deck.",
    "Monstro 1: no máximo 3 cópias somando Main e Extra (tem 4).",
    "Monstro 2 não é de Fusão nem Sincro: não vai no Extra Deck.",
    "Monstro 3: você tem 1 e o deck usa 2.",
    "Pote está proibida.",
    "Raio é limitada: no máximo 1 cópia (tem 2).",
  ]);
});

test("adicionar soma na linha da seção e para em 3 cópias da carta no deck todo", () => {
  let rows: DeckRow[] = [];
  rows = editDeck(rows, { type: "add", cardId: 1, section: "main" });
  rows = editDeck(rows, { type: "add", cardId: 1, section: "main" });
  rows = editDeck(rows, { type: "add", cardId: 1, section: "extra" });
  rows = editDeck(rows, { type: "add", cardId: 1, section: "extra" });

  assert.deepEqual(rows, [row(1, "main", 2), row(1, "extra", 1)]);
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

test("o baú diz por que não dá para pôr mais uma: 3 cópias no deck ou a seção cheia", () => {
  const three = [row(100, "main", 1), row(100, "extra", 2)];
  assert.equal(addBlocked(three, 100, "main"), "Já tem 3 no deck.");
  assert.equal(addBlocked(three, 100, "extra"), "Já tem 3 no deck.");

  const full = Array.from({ length: 20 }, (_, i) => row(i + 1, "main", 3));
  assert.equal(addBlocked(full, 21, "main"), "Main Deck cheio.");
  assert.equal(addBlocked(full, 100, "extra"), undefined);
  const fullExtra = Array.from({ length: 5 }, (_, i) => row(101 + i, "extra", 3));
  assert.equal(addBlocked(fullExtra, 100, "extra"), "Extra Deck cheio.");
  // A banlist depende da sala, e o deck pode ser rascunho: proibida e repetida entram.
  assert.equal(addBlocked([], 50, "main"), undefined);
});

test("seção cheia não cresce, nem pelo botão, nem arrastando", () => {
  const full = Array.from({ length: 20 }, (_, i) => row(i + 1, "main", 3));

  assert.deepEqual(editDeck(full, { type: "add", cardId: 21, section: "main" }), full);
});

test("a contagem já diz quando o deck não duela, antes de ir ao servidor", () => {
  assert.equal(deckSizeProblem({ main: 40, extra: 15 }), undefined);
  assert.equal(
    deckSizeProblem({ main: 3, extra: 0 }),
    "O Main Deck tem 3 cartas: precisa ter de 40 a 60.",
  );
  assert.equal(
    deckSizeProblem({ main: 40, extra: 16 }),
    "O Extra Deck tem 16 cartas: pode ter até 15.",
  );
});

// Cartas com o tipo, para o resumo e a ordem da grade do deck.
const typed = new Map<number, CardSummary>(
  [
    { id: 1, name: "Zebra", card_type: "Monster" as const },
    { id: 2, name: "Armadilha", card_type: "Trap" as const },
    { id: 3, name: "Alfa", card_type: "Monster" as const },
    { id: 4, name: "Magia", card_type: "Spell" as const },
    { id: 5, name: "Herói", card_type: "Monster" as const, monster_types: ["Fusion"] },
  ].map((card) => [card.id, card]),
);

test("o resumo da seção conta monstros, magias e armadilhas", () => {
  const rows = [row(1, "main", 3), row(2, "main", 1), row(4, "main", 2), row(5, "extra", 2)];

  assert.deepEqual(typeCounts(rows, typed, "main"), { Monster: 3, Spell: 2, Trap: 1 });
  assert.deepEqual(typeCounts(rows, typed, "extra"), { Monster: 2, Spell: 0, Trap: 0 });
});

test("a grade do deck põe monstros, magias e armadilhas, cada grupo pelo nome", () => {
  const rows = [row(2, "main", 1), row(4, "main", 1), row(1, "main", 1), row(3, "main", 1)];

  assert.deepEqual(
    deckOrder(rows, typed, "en").map((item) => item.card_id),
    [3, 1, 4, 2],
  );
});
