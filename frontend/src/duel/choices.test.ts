import { test } from "node:test";
import assert from "node:assert/strict";
import { atLeastSum, canConfirm, exactSum, progress } from "./choices.ts";

const card = (extra: Record<string, number> = {}) => ({
  code: 1,
  controller: 0,
  location: 4,
  sequence: 0,
  ...extra,
});
// O "sum" da engine: o valor normal nos 16 bits de baixo e o outro, se houver, nos de cima.
const level = (normal: number, other = 0) => normal | (other << 16);

test("soma exata: chega ao total com um dos dois valores de cada carta", () => {
  assert.equal(exactSum([level(4), level(4)], 8), true);
  assert.equal(exactSum([level(4), level(3)], 8), false);
  assert.equal(exactSum([level(4), level(1, 4)], 8), true);
  assert.equal(exactSum([], 8), false);
});

test("soma de pelo menos: passa do total, mas sem a menor carta já não passaria", () => {
  assert.equal(atLeastSum([level(4), level(4)], 7), true);
  assert.equal(atLeastSum([level(4), level(4), level(1)], 8), false);
  assert.equal(atLeastSum([level(4)], 8), false);
});

test("só libera o Confirmar quando a engine vai aceitar a escolha", () => {
  const cards = [card(), card(), card({ release_param: 2 })];
  const select = { type: "select_card", player: 0, min: 2, max: 2, cards };
  assert.equal(canConfirm(select, [0]), false);
  assert.equal(canConfirm(select, [0, 1]), true);
  assert.equal(canConfirm({ ...select, min: 0, max: 1 }, []), false);
  assert.equal(progress(select, [0]), "Escolhidas: 1 de 2");
  assert.equal(progress({ ...select, min: 1, max: 3 }, [0]), "Escolhidas: 1 (de 1 a 3)");

  const tribute = { ...select, type: "select_tribute" };
  assert.equal(canConfirm(tribute, [2]), true);
  assert.equal(canConfirm(tribute, [0]), false);
  assert.equal(progress(tribute, [2]), "Tributos: 2 de 2");

  const sum = {
    type: "select_sum",
    player: 0,
    select_max: true,
    acc: 8,
    min: 1,
    max: 2,
    must: [card({ sum: level(4) })],
    cards: [card({ sum: level(4) }), card({ sum: level(3) })],
  };
  assert.equal(canConfirm(sum, [0]), true);
  assert.equal(canConfirm(sum, [1]), false);
  assert.equal(canConfirm({ ...sum, select_max: false, acc: 7 }, [1]), true);
  assert.equal(progress(sum, [1]), "Total: 7 de 8");
});
