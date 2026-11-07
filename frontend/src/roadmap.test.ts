import { test } from "node:test";
import assert from "node:assert/strict";
import { currentPhase, PHASES, type Phase } from "./roadmap.ts";

test("a fase atual é a primeira que ainda não terminou", () => {
  const phases: Phase[] = [
    { code: "F0", name: "A", done: true },
    { code: "F1", name: "B", done: false },
    { code: "F2", name: "C", done: false },
  ];
  assert.equal(currentPhase(phases)?.code, "F1");
});

test("sem fase aberta, não há fase atual", () => {
  assert.equal(currentPhase([{ code: "F0", name: "A", done: true }]), undefined);
});

test("o roteiro tem as oito fases do escopo, na ordem", () => {
  assert.deepEqual(
    PHASES.map((phase) => phase.code),
    ["F0", "F1", "F2", "F3", "F4", "F5", "F6", "F7"],
  );
});
