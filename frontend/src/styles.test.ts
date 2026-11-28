import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

// Os seletores de primeiro nível do styles.css (fora de @media), um por regra.
function topSelectors(css: string) {
  const selectors: string[] = [];
  let depth = 0;
  let current = "";
  for (const char of css.replace(/\/\*[\s\S]*?\*\//g, "")) {
    if (char === "{") {
      if (depth === 0) selectors.push(current.trim().replace(/\s+/g, " "));
      depth += 1;
      current = "";
    } else if (char === "}") {
      depth -= 1;
      current = "";
    } else if (depth === 0) {
      current = char === ";" ? "" : current + char;
    }
  }
  return selectors.filter((selector) => !selector.startsWith("@"));
}

// Cada seletor aparece numa regra só: duas regras com o mesmo seletor, longe uma da outra,
// já deixaram a classe de uma tela mudar outra (a barra da loja quebrou a lista da coleção).
test("o styles.css não repete o mesmo seletor em duas regras", () => {
  const css = readFileSync(new URL("./styles.css", import.meta.url), "utf8");
  const selectors = topSelectors(css);
  const repeated = selectors.filter((selector, index) => selectors.indexOf(selector) !== index);
  assert.deepEqual(repeated, []);
});

test("a leitura dos seletores ignora comentários, @media e o que vem dentro das regras", () => {
  const css = `/* .a {} */ .a { color: red; .b { color: blue; } } @media (width > 1px) { .a { x: y; } } .c,\n.d { x: y; }`;
  assert.deepEqual(topSelectors(css), [".a", ".c, .d"]);
});
