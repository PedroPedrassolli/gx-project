import { test } from "node:test";
import assert from "node:assert/strict";
import { decisionChip, decisionText, duelChip, fromSelect } from "./times.ts";

test("o tempo de resposta sai em minutos e segundos, sem zero sobrando", () => {
  assert.deepEqual([30, 60, 90, 180].map(decisionText), ["30 s", "1 min", "1 min 30 s", "3 min"]);
});

test("as fichas dizem o tempo ou que não tem limite", () => {
  assert.deepEqual(
    [decisionChip(90), decisionChip(null), duelChip(60), duelChip(null)],
    ["1 min 30 s por resposta", "Resposta sem limite", "Duelo de 60 min", "Duelo sem limite"],
  );
});

test("o select vazio é sem limite", () => {
  assert.deepEqual([fromSelect(""), fromSelect("30")], [null, 30]);
});
