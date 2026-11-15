import { test } from "node:test";
import assert from "node:assert/strict";
import { clock } from "./time.ts";

test("o relógio mostra minutos e segundos, arredondando para cima e sem ficar negativo", () => {
  assert.equal(clock(65_000), "1:05");
  assert.equal(clock(59_001), "1:00");
  assert.equal(clock(-3_000), "0:00");
  assert.equal(clock(3_600_000), "60:00");
});
