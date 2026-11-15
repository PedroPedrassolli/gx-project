import { test } from "node:test";
import assert from "node:assert/strict";
import { announceOptions, freeZones, searchCards } from "./announce.ts";

test("as zonas livres saem do flag, dos dois lados, com o nome de cada uma", () => {
  // Livres: a zona de monstro 3 de quem escolhe (bit 2) e a de campo do oponente (bit 29).
  const flag = 0xffffffff & ~(1 << 2) & ~(1 << 29);
  const zones = freeZones({ type: "select_disfield", player: 1, count: 1, flag });
  assert.deepEqual(zones, [
    { player: 1, location: 4, sequence: 2, label: "Sua zona de monstro, 3ª da esquerda" },
    { player: 0, location: 8, sequence: 5, label: "Zona de campo do oponente" },
  ]);
});

test("o anúncio de tipo e de atributo só mostra o que a engine deixa", () => {
  const races = announceOptions({
    type: "announce_race",
    player: 0,
    count: 1,
    available: 0x1 | 0x2000,
  });
  assert.deepEqual(races, [
    { bit: 0x1, label: "Guerreiro" },
    { bit: 0x2000, label: "Dragão" },
  ]);
  const attributes = announceOptions({
    type: "announce_attrib",
    player: 0,
    count: 1,
    available: 0x20,
  });
  assert.deepEqual(attributes, [{ bit: 0x20, label: "TREVAS" }]);
});

test("a busca do nome ignora acento e caixa e põe primeiro o nome que começa igual", () => {
  const cards = [
    { id: 1, code: 10, name: "Blue-Eyes White Dragon", name_pt: "Dragão Branco de Olhos Azuis" },
    { id: 2, code: 20, name: "Dragon Capture Jar", name_pt: "Jarro de Captura de Dragões" },
    { id: 3, name: "Sem código" },
  ];
  const codes = (query: string, language: "pt" | "en") =>
    searchCards(cards, query, language).map((card) => card.code);
  assert.deepEqual(codes("drag", "pt"), [10, 20]);
  assert.deepEqual(codes("drag", "en"), [20, 10]);
  assert.deepEqual(codes("DRAGOES", "pt"), [20]);
  assert.deepEqual(searchCards(cards, "d", "pt"), []);
});
