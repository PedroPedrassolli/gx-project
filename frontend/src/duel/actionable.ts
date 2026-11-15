import type { Place, Prompt } from "./api.ts";

// As listas da pergunta que apontam cartas (Duel::View::PROMPT_LISTS, menos as que a carta
// deixa de ser escolhida).
const LISTS = [
  "summonable",
  "spsummonable",
  "repositionable",
  "msetable",
  "ssetable",
  "activatable",
  "attackable",
  "cards",
  "must",
  "selectable",
  "chains",
];

// Onde estão as cartas que a pergunta da vez deixa usar: "time-local-posição" para a carta
// e "time-local" para a pilha (cemitério, banidas, Extra, deck). A mesa faz essas cartas
// brilharem; escolher continua sendo nos botões da pergunta.
export function actionablePlaces(prompt?: Prompt): Set<string> {
  const places = new Set<string>();
  for (const key of LISTS) {
    const list = prompt?.[key];
    if (!Array.isArray(list)) continue;
    for (const card of list as Place[]) {
      places.add(`${card.controller}-${card.location}-${card.sequence}`);
      places.add(`${card.controller}-${card.location}`);
    }
  }
  return places;
}
