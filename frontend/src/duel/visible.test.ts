import { test } from "node:test";
import assert from "node:assert/strict";
import type { Side, View } from "./api.ts";
import { visibleCodes } from "./visible.ts";

const side = (more: Partial<Side>): Side => ({
  team: 0,
  lp: 8000,
  deck: 30,
  extra: 0,
  hand: [],
  monsters: [null, null, null, null, null],
  spells: [null, null, null, null, null],
  grave: [],
  banished: [],
  ...more,
});

test("junta as cartas à vista dos dois lados e da corrente, sem repetir e sem as viradas", () => {
  const view: View = {
    you: 0,
    turn: 3,
    turn_team: 0,
    sides: [
      side({
        hand: [{ code: 1 }, { hidden: true }],
        monsters: [{ code: 2, face_down: false, defense: false }, null, null, null, null],
        grave: [{ code: 1 }],
        extra_cards: [{ code: 5 }],
      }),
      side({
        team: 1,
        monsters: [{ face_down: true, defense: true }, null, null, null, null],
        spells: [{ code: 3, face_down: false, defense: false }, null, null, null, null],
        field_spell: { code: 4, face_down: false, defense: false },
        banished: [{ code: 6 }],
      }),
    ],
    chain: [{ code: 7, link: 1, controller: 1, location: 8, sequence: 0, position: 1 }],
  };
  assert.deepEqual(
    visibleCodes(view).sort((a, b) => a - b),
    [1, 2, 3, 4, 5, 6, 7],
  );
});
