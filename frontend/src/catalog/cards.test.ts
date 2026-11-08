import { test } from "node:test";
import assert from "node:assert/strict";
import {
  EMPTY_FILTERS,
  frame,
  matches,
  plain,
  sortCards,
  typeLine,
  type CardSummary,
} from "./cards.ts";
import { ATTRIBUTES, label } from "./labels.ts";

const cards: CardSummary[] = [
  {
    id: 1,
    name: "Dark Magician",
    name_pt: "Mago Negro",
    card_type: "Monster",
    attribute: "DARK",
    race: "Spellcaster",
    monster_types: ["Normal"],
    level: 7,
    atk: 2500,
    def: 2100,
  },
  {
    id: 2,
    name: "Pot of Greed",
    name_pt: "Pote da Ganância",
    card_type: "Spell",
    property: "Normal",
  },
  {
    id: 3,
    name: "The Wicked Avatar",
    card_type: "Monster",
    attribute: "DARK",
    race: "Fiend",
    monster_types: ["Effect"],
    level: 10,
    def: 0,
  },
  {
    id: 4,
    name: "Stardust Dragon",
    name_pt: "Dragão da Poeira Estelar",
    card_type: "Monster",
    attribute: "WIND",
    race: "Dragon",
    monster_types: ["Synchro", "Effect"],
    level: 8,
    atk: 2500,
    def: 2000,
  },
];
const names = (list: CardSummary[]) => list.map((card) => card.name);
const filter = (changes: Partial<typeof EMPTY_FILTERS>) =>
  names(cards.filter((card) => matches(card, { ...EMPTY_FILTERS, ...changes })));

test("busca pelo nome em português ou em inglês, sem acento e sem caixa", () => {
  assert.equal(plain("Dragão"), "dragao");
  assert.deepEqual(filter({ q: "DRAGAO" }), ["Stardust Dragon"]);
  assert.deepEqual(filter({ q: "magician" }), ["Dark Magician"]);
});

test("filtra por tipo, atributo, raça, tipo de monstro e nível", () => {
  assert.deepEqual(filter({ cardType: "Spell" }), ["Pot of Greed"]);
  assert.deepEqual(filter({ attribute: "DARK", race: "Fiend" }), ["The Wicked Avatar"]);
  assert.deepEqual(filter({ monsterType: "Effect", level: "8" }), ["Stardust Dragon"]);
});

test("a faixa de ATK deixa de fora quem tem ATK ?", () => {
  assert.deepEqual(filter({ atkMin: "2000" }), ["Dark Magician", "Stardust Dragon"]);
  assert.deepEqual(filter({ defMax: "0" }), ["The Wicked Avatar"]);
});

test("ordena pelo nome exibido e pelos números, com quem não tem valor no fim", () => {
  assert.deepEqual(names(sortCards(cards, EMPTY_FILTERS, "pt")), [
    "Stardust Dragon",
    "Dark Magician",
    "Pot of Greed",
    "The Wicked Avatar",
  ]);
  const byAtk = sortCards(cards, { ...EMPTY_FILTERS, sort: "atk", order: "desc" }, "en");
  assert.deepEqual(names(byAtk), [
    "Dark Magician",
    "Stardust Dragon",
    "Pot of Greed",
    "The Wicked Avatar",
  ]);
});

test("escolhe a moldura e traduz os valores", () => {
  assert.deepEqual(cards.map(frame), ["normal", "spell", "effect", "synchro"]);
  assert.equal(label(ATTRIBUTES, "DARK"), "TREVAS");
  assert.equal(label(ATTRIBUTES, "NEW"), "NEW");
});

test("monta a linha de tipo em português", () => {
  assert.deepEqual(cards.map(typeLine), [
    "Mago / Normal",
    "Magia Normal",
    "Demônio / Efeito",
    "Dragão / Sincro / Efeito",
  ]);
  assert.equal(
    typeLine({ id: 5, name: "Sogen", card_type: "Spell", property: "Field" }),
    "Magia de Campo",
  );
});
