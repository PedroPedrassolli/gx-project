import type { CardSummary, Language } from "../catalog/cards.ts";
import { CardPanel, useMediaQuery } from "../catalog/CardPanel.tsx";

// O detalhe da carta tocada na mesa (no duelo e no replay): o painel da carta, ou o convite
// para tocar numa, que só aparece no computador.
export function DuelDetail(props: {
  code: number | null;
  cards: Map<number, CardSummary>;
  packs: Map<number, string>;
  language: Language;
  onClose: () => void;
}) {
  const wide = useMediaQuery("(width >= 72rem)");
  const card = props.code === null ? undefined : props.cards.get(props.code);
  if (card) {
    return (
      <CardPanel
        cardId={card.id}
        language={props.language}
        packs={props.packs}
        wide={wide}
        onClose={props.onClose}
        className="duel-detail"
      />
    );
  }
  return (
    <section className="duel-detail duel-detail-empty" aria-labelledby="detail-empty-title">
      <h2 id="detail-empty-title">Carta</h2>
      <p>Toque numa carta para ver o detalhe dela.</p>
    </section>
  );
}
