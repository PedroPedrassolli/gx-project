import type { View } from "./api.ts";

// As cartas da mesa que o jogador pode tocar para ver o detalhe: as que estão à vista nos dois
// lados (mão, campo, cemitério, banidas e o Extra dele) e as da corrente, sem repetir. Carta
// virada para baixo (ou na mão do outro) vem sem código e fica de fora.
export function visibleCodes(view: View): number[] {
  const codes = new Set<number>();
  for (const side of view.sides) {
    const cards = [
      ...side.hand,
      ...side.monsters,
      ...side.spells,
      side.field_spell,
      ...side.grave,
      ...side.banished,
      ...(side.extra_cards ?? []),
    ];
    for (const card of cards) if (card?.code) codes.add(card.code);
  }
  for (const link of view.chain ?? []) codes.add(link.code);
  return [...codes];
}
