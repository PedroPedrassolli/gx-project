import { test } from "node:test";
import assert from "node:assert/strict";
import { visibleEmotes, withEmote } from "./emotes.ts";

const at = "2026-11-15T18:00:00.000Z";
const now = Date.parse(at);

test("a frase aparece por alguns segundos e some; frase desconhecida não aparece", () => {
  const players = [
    { team: 0, emote: "nice", emote_at: at },
    { team: 1, emote: "xingamento", emote_at: at },
  ];
  assert.deepEqual([...visibleEmotes(players, now + 1000)], [[0, "Boa jogada!"]]);
  assert.deepEqual([...visibleEmotes(players, now + 6000)], []);
});

test("a frase que chega entra no jogador certo", () => {
  const state = { id: 5, players: [{ team: 0 }, { team: 1 }] };
  assert.deepEqual(withEmote(state, { team: 1, emote: "gg", emote_at: at }).players, [
    { team: 0 },
    { team: 1, emote: "gg", emote_at: at },
  ]);
});
