import type { CardDetail, CardSummary } from "../catalog/cards.ts";
import type { EngineCard } from "./api.ts";

// As cartas que só a engine conhece (as fichas, as cartas que um efeito cria) chegam com a
// mesa (GXP-141) e entram no mesmo índice do catálogo: a mesa, o histórico e o detalhe acham
// a carta pelo código. O id negativo marca que ela não está no catálogo (e já traz o texto).
export function withEngineCards(
  byCode: Map<number, CardSummary>,
  extras: (Record<string, EngineCard> | undefined)[],
): Map<number, CardSummary> {
  const cards = extras.flatMap((extra) => Object.values(extra ?? {}));
  if (cards.length === 0) return byCode;
  const merged = new Map(byCode);
  for (const card of cards) merged.set(card.code, { ...card, id: -card.code } satisfies CardDetail);
  return merged;
}
