import { test } from "node:test";
import assert from "node:assert/strict";
import { describe } from "./log.ts";

const cards = new Map([
  [46986414, { id: 1, code: 46986414, name: "Dark Magician", name_pt: "Mago Negro" }],
  [89631139, { id: 2, code: 89631139, name: "Blue-Eyes White Dragon" }],
]);
const ctx = { you: 0, names: ["JadenYuki", "Syrus"], cards, language: "pt" as const };
const line = (event: Record<string, unknown>) => describe({ id: 1, type: "", ...event }, ctx);
const at = (controller: number, location: number, sequence = 0, position = 0x1) => ({
  controller,
  location,
  sequence,
  position,
});

test("o turno, a fase principal e a compra viram uma linha para cada lado", () => {
  assert.equal(line({ type: "turn", team: 1 }), "Novo turno: vez de Syrus.");
  assert.equal(line({ type: "phase", phase: 0x08 }), "Fase: Batalha.");
  assert.equal(line({ type: "phase", phase: 0x20 }), null);
  assert.equal(line({ type: "draw", team: 0, codes: [46986414] }), "Você comprou Mago Negro.");
  assert.equal(line({ type: "draw", team: 1, count: 2 }), "Syrus comprou 2 cartas.");
});

test("invocação, carta baixada e carta que muda de lugar", () => {
  const summon = { type: "summon", code: 89631139, ...at(1, 4, 2) };
  assert.equal(line({ ...summon, kind: "normal" }), "Syrus invocou Blue-Eyes White Dragon.");
  assert.equal(
    line({ ...summon, kind: "special" }),
    "Syrus invocou Blue-Eyes White Dragon por Invocação-Especial.",
  );
  assert.equal(line({ type: "set", code: 0, ...at(1, 8) }), "Syrus baixou uma magia ou armadilha.");
  const move = (code: number, from: object, to: object, reason = 0) =>
    line({ type: "move", code, from, to, reason });
  assert.equal(
    move(46986414, at(0, 4), at(0, 16), 0x21),
    "A carta Mago Negro foi destruída em batalha.",
  );
  assert.equal(move(0, at(1, 2), at(1, 16), 0x4000), "Uma carta foi descartada.");
  assert.equal(move(0, at(1, 1), at(1, 2)), "Syrus adicionou uma carta do Deck à mão.");
  assert.equal(move(46986414, at(0, 2, 0, 10), at(0, 4)), null, "a invocação já conta");
});

test("corrente, ataque, PV e o fim", () => {
  assert.equal(
    line({ type: "chain", code: 46986414, ...at(0, 4), link: 1 }),
    "Elo 1: você ativou Mago Negro.",
  );
  assert.equal(line({ type: "chain_negated", link: 1 }), "O elo 1 foi negado.");
  assert.equal(line({ type: "chain_solved", link: 1 }), null);
  const attacker = { ...at(0, 4, 2), code: 46986414 };
  assert.equal(
    line({ type: "attack", attacker, target: at(1, 4, 0, 0x8) }),
    "Mago Negro atacou um monstro com a face para baixo.",
  );
  assert.equal(line({ type: "attack", attacker, target: null }), "Mago Negro atacou diretamente.");
  assert.equal(
    line({ type: "lp", kind: "damage", team: 1, amount: 2500 }),
    "Syrus perdeu 2.500 PV.",
  );
  assert.equal(line({ type: "lp", kind: "cost", team: 0, amount: 800 }), "Você pagou 800 PV.");
  assert.equal(line({ type: "win", player: 1, reason: 0 }), "Syrus venceu.");
  assert.equal(line({ type: "win", player: 2, reason: 0 }), "Empate.");
});
