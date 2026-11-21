import { test } from "node:test";
import assert from "node:assert/strict";
import { commands, commandsByPlace, isCommandPrompt, phaseCommands } from "./commands.ts";

const hand = (sequence: number, code: number) => ({ code, controller: 0, location: 2, sequence });

test("as ações de cada carta ficam juntas, com o índice de cada lista", () => {
  const prompt = {
    type: "select_idlecmd",
    player: 0,
    summonable: [hand(0, 1), hand(2, 3)],
    msetable: [hand(0, 1)],
    activatable: [
      { code: 9, controller: 0, location: 8, sequence: 1, text: "Efeito 1" },
      { code: 9, controller: 0, location: 8, sequence: 1, text: "Efeito 2" },
    ],
  };
  const byPlace = commandsByPlace(prompt);

  assert.deepEqual(
    byPlace.get("0-2-0")?.map((item) => [item.verb, item.command, item.index]),
    [
      ["Invocar", "summon", 0],
      ["Baixar", "mset", 0],
    ],
  );
  assert.deepEqual(
    byPlace.get("0-8-1")?.map((item) => [item.command, item.index, item.card.text]),
    [
      ["activate", 0, "Efeito 1"],
      ["activate", 1, "Efeito 2"],
    ],
  );
  assert.equal(commands(prompt).length, 5);
});

test("na batalha, atacar e ativar; nas outras perguntas, nada", () => {
  const prompt = {
    type: "select_battlecmd",
    player: 0,
    attackable: [{ code: 5, controller: 0, location: 4, sequence: 0 }],
  };
  assert.deepEqual(
    commands(prompt).map((item) => [item.verb, item.prefix]),
    [["Atacar", "Atacar com"]],
  );
  assert.equal(isCommandPrompt({ type: "select_chain", player: 0 }), false);
  assert.deepEqual(commands({ type: "select_chain", player: 0 }), []);
});

test("os botões de fase seguem o que a pergunta deixa", () => {
  assert.deepEqual(
    phaseCommands({ type: "select_idlecmd", player: 0, to_bp: true, to_ep: true }).map(
      (item) => item.command,
    ),
    ["battle", "end"],
  );
  assert.deepEqual(
    phaseCommands({ type: "select_battlecmd", player: 0, to_m2: true, to_ep: false }),
    [{ label: "Ir para a Principal 2", command: "main2" }],
  );
  assert.deepEqual(phaseCommands({ type: "select_yesno", player: 0 }), []);
});
