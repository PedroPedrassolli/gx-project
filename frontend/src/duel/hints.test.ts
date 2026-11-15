import { test } from "node:test";
import assert from "node:assert/strict";
import { hintText, systemText } from "./hints.ts";

test("a dica vem do texto da carta ou dos textos do jogo", () => {
  assert.equal(
    hintText({ type: "select_card", player: 0, hint: 502 }),
    "Escolha a carta para destruir",
  );
  assert.equal(
    hintText({ type: "select_card", player: 0, hint: 1 << 20, hint_text: "Target 1 card" }),
    "Target 1 card",
  );
  assert.equal(hintText({ type: "select_card", player: 0 }), undefined);
});

test("os textos do jogo no sim ou não e nas opções, com o nome e o lugar da carta", () => {
  assert.equal(systemText(30), "Houve um replay. Continuar o ataque?");
  assert.equal(
    systemText(96, "Mago Negro"),
    "Usar o efeito de “Mago Negro” para não ser destruída?",
  );
  assert.equal(
    systemText(221, "Mago Negro", "cemitério"),
    "Ativar o efeito de gatilho de “Mago Negro” (cemitério)?",
  );
  assert.equal(systemText(200, "Mago Negro"), "Usar o efeito de “Mago Negro”?");
  assert.equal(systemText(1213), "Sim");
  // Descrição de carta (código << 20) vem pronta do servidor; aqui não tem texto.
  assert.equal(systemText(46986414 * 2 ** 20 + 1), undefined);
  assert.equal(systemText(undefined), undefined);
});
