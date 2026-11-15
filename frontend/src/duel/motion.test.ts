import { test } from "node:test";
import assert from "node:assert/strict";
import { lastId, lpChanges } from "./motion.ts";

test("lpChanges guarda a última mudança de PV de cada time", () => {
  const events = [
    { id: 1, type: "lp", team: 1, kind: "damage", amount: 500 },
    { id: 2, type: "draw", team: 0, count: 1 },
    { id: 3, type: "lp", team: 1, kind: "recover", amount: 1000 },
    { id: 4, type: "lp", team: 0, kind: "cost", amount: 800 },
  ];
  const changes = lpChanges(events);
  assert.deepEqual([...changes.keys()].sort(), [0, 1]);
  assert.equal(changes.get(1)?.id, 3);
  assert.equal(changes.get(0)?.kind, "cost");
});

test("lastId é o maior id, ou 0 sem eventos", () => {
  assert.equal(lastId([]), 0);
  assert.equal(
    lastId([
      { id: 7, type: "turn" },
      { id: 3, type: "phase" },
    ]),
    7,
  );
});
