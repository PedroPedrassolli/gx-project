import { test } from "node:test";
import assert from "node:assert/strict";
import { handName, roundText } from "./opening.ts";

test("o nome da mão vem em minúsculas, para o meio da frase", () => {
  assert.deepEqual(
    ["rock", "paper", "scissors"].map((hand) => handName(hand as never)),
    ["pedra", "papel", "tesoura"],
  );
});

test("a rodada diz o que cada um tirou e quem ganhou, ou que empatou", () => {
  assert.equal(
    roundText({ "0": "rock", "1": "scissors" }, 0, "Syrus"),
    "Você tirou pedra e Syrus, tesoura: você ganhou.",
  );
  assert.equal(
    roundText({ "0": "rock", "1": "paper" }, 0, "Syrus"),
    "Você tirou pedra e Syrus, papel: Syrus ganhou.",
  );
  assert.equal(
    roundText({ "0": "paper", "1": "paper" }, 1, "Jaden"),
    "Empate: os dois tiraram papel. De novo!",
  );
  assert.equal(roundText({ "0": "rock" }, 0, "Syrus"), "");
});
