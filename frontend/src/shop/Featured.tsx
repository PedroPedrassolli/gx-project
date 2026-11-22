import { CardImage } from "../catalog/CardImage.tsx";
import { IMAGE_WIDTHS, type CardSummary } from "../catalog/cards.ts";
import { RARITIES, label } from "../catalog/labels.ts";

// A carta em destaque (GXP-138): grande, com o brilho atrás e o reflexo holográfico por cima,
// e embaixo a raridade, o nome e se é nova. A abertura de pacote usa para a mais rara; o
// conversor, para a carta que saiu.
export function FeaturedCard(props: {
  card: CardSummary | undefined;
  name: string;
  rarity?: string;
  isNew: boolean;
}) {
  return (
    <span className="featured-card">
      <span className={`foil${props.rarity ? ` rarity-${props.rarity}` : ""}`}>
        <CardImage
          card={props.card}
          size="m"
          width={IMAGE_WIDTHS.m}
          height={391}
          alt={props.name}
        />
      </span>
      <span className="featured-label">
        {props.rarity && (
          <span className={`rarity rarity-${props.rarity}`}>{label(RARITIES, props.rarity)}</span>
        )}
        <strong>{props.name}</strong>
        {props.isNew && <span className="new-card">Nova na sua coleção</span>}
      </span>
    </span>
  );
}
