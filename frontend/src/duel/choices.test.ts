import { test } from "node:test";
import assert from "node:assert/strict";
import { canConfirm, progress } from "./choices.ts";

const card = { code: 1, controller: 0, location: 4, sequence: 0 };

test("só libera o Confirmar quando a engine vai aceitar a escolha", () => {
  const select = { type: "select_card", player: 0, min: 2, max: 2, cards: [card, card, card] };
  assert.equal(canConfirm(select, [0]), false);
  assert.equal(canConfirm(select, [0, 1]), true);
  assert.equal(canConfirm({ ...select, min: 0, max: 1 }, []), false);
  assert.equal(progress(select, [0]), "Escolhidas: 1 de 2");
  assert.equal(progress({ ...select, min: 1, max: 3 }, [0]), "Escolhidas: 1 (de 1 a 3)");
});
