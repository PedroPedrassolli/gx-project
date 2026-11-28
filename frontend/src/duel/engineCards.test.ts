import assert from "node:assert/strict";
import { test } from "node:test";
import type { CardSummary } from "../catalog/cards.ts";
import { withEngineCards } from "./engineCards.ts";

const magician: CardSummary = { id: 1, code: 46986414, name: "Dark Magician" };
const token = {
  code: 46173680,
  name: "Doomsday Token",
  card_type: "Monster" as const,
  monster_types: ["Token"],
  text: "Special Summoned with the effect of Fires of Doomsday.",
};

test("sem carta de fora do catálogo, devolve o próprio índice", () => {
  const byCode = new Map([[magician.code!, magician]]);
  assert.equal(withEngineCards(byCode, [undefined, {}]), byCode);
});

test("junta as fichas da mesa ao índice, com id negativo, sem mexer no catálogo", () => {
  const byCode = new Map([[magician.code!, magician]]);
  const cards = withEngineCards(byCode, [{ "46173680": token }]);

  assert.deepEqual(cards.get(46173680), { ...token, id: -46173680 });
  assert.equal(cards.get(46986414), magician);
  assert.equal(byCode.size, 1);
});
