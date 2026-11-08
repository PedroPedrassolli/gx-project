import { test } from "node:test";
import assert from "node:assert/strict";
import { pageTitle } from "./pageTitle.ts";

test("o título da aba traz a página antes do nome do site", () => {
  assert.equal(pageTitle("Coleção"), "Coleção · GX Project");
});

test("sem página, fica só o nome do site", () => {
  assert.equal(pageTitle(), "GX Project");
  assert.equal(pageTitle(""), "GX Project");
});
