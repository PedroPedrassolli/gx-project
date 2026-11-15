import { test } from "node:test";
import assert from "node:assert/strict";
import { freeZones } from "./announce.ts";

test("as zonas livres saem do flag, dos dois lados, com o nome de cada uma", () => {
  // Livres: a zona de monstro 3 de quem escolhe (bit 2) e a de campo do oponente (bit 29).
  const flag = 0xffffffff & ~(1 << 2) & ~(1 << 29);
  const zones = freeZones({ type: "select_disfield", player: 1, count: 1, flag });
  assert.deepEqual(zones, [
    { player: 1, location: 4, sequence: 2, label: "Sua zona de monstro 3" },
    { player: 0, location: 8, sequence: 5, label: "Zona de campo do oponente" },
  ]);
});
