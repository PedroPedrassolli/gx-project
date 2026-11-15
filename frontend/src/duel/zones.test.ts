import { test } from "node:test";
import assert from "node:assert/strict";
import { placeLabel, zoneName } from "./zones.ts";

test("a zona conta da esquerda como a mesa aparece, e a do oponente é espelhada", () => {
  assert.equal(zoneName(4, 0, true), "sua zona de monstro, 1ª da esquerda");
  assert.equal(zoneName(4, 0, false), "zona de monstro do oponente, 5ª da esquerda");
  assert.equal(zoneName(8, 3, false), "zona de magia e armadilha do oponente, 2ª da esquerda");
  assert.equal(zoneName(8, 5, true), "sua zona de campo");
});

test("o lugar da carta diz a zona, se a sua está virada, e a pilha", () => {
  const you = 0;
  assert.equal(
    placeLabel({ controller: 0, location: 4, sequence: 1, position: 0x8 }, you),
    "sua zona de monstro, 2ª da esquerda, virada para baixo",
  );
  // A do oponente virada já se chama "Carta virada": o lugar não repete.
  assert.equal(
    placeLabel({ controller: 1, location: 4, sequence: 1, position: 0x8 }, you),
    "zona de monstro do oponente, 4ª da esquerda",
  );
  assert.equal(placeLabel({ controller: 0, location: 2, sequence: 0 }, you), "mão");
  assert.equal(
    placeLabel({ controller: 1, location: 16, sequence: 3 }, you),
    "cemitério do oponente",
  );
  assert.equal(placeLabel({ controller: 0, location: 0x80, sequence: 0 }, you), undefined);
});
