import { test } from "node:test";
import assert from "node:assert/strict";
import { actionablePlaces } from "./actionable.ts";

test("actionablePlaces junta a carta e a pilha de cada lista da pergunta", () => {
  const places = actionablePlaces({
    type: "select_idlecmd",
    player: 0,
    summonable: [{ code: 1, controller: 0, location: 2, sequence: 0 }],
    activatable: [{ code: 2, controller: 0, location: 16, sequence: 3 }],
    to_bp: true,
  });
  assert.deepEqual([...places].sort(), ["0-16", "0-16-3", "0-2", "0-2-0"]);
});

test("sem pergunta, nada brilha", () => {
  assert.equal(actionablePlaces(undefined).size, 0);
});
