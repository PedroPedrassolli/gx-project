import { test } from "node:test";
import assert from "node:assert/strict";
import { hintText } from "./hints.ts";

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
