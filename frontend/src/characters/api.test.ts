import { test } from "node:test";
import assert from "node:assert/strict";
import { byGroup, nextCharacter, type Character } from "./api.ts";

const character = (id: string, group: string, position: number): Character => ({
  id,
  position,
  name: id,
  description: "",
  group: { id: group, name: group.toUpperCase() },
  deck: "",
  bonus: 60 * position,
  wins: 0,
  status: "locked",
});

test("junta os personagens por grupo, na ordem em que vêm", () => {
  const groups = byGroup([
    character("chumley", "alunos", 1),
    character("syrus", "alunos", 2),
    character("zane", "chefes", 3),
    character("yugi", "lendas", 4),
  ]);

  assert.deepEqual(
    groups.map((group) => [group.id, group.name, group.characters.map((item) => item.id)]),
    [
      ["alunos", "ALUNOS", ["chumley", "syrus"]],
      ["chefes", "CHEFES", ["zane"]],
      ["lendas", "LENDAS", ["yugi"]],
    ],
  );
  assert.deepEqual(byGroup([]), []);
});

test("o próximo desafiante é o primeiro liberado que ainda não foi vencido", () => {
  const beaten = { ...character("chumley", "alunos", 1), status: "beaten" as const, wins: 2 };
  const open = { ...character("syrus", "alunos", 2), status: "unlocked" as const };
  const locked = character("blair", "alunos", 3);

  assert.equal(nextCharacter([beaten, open, locked])?.id, "syrus");
  assert.equal(nextCharacter([beaten]), undefined);
});
