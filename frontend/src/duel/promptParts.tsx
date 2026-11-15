import { displayName, imageUrl, type CardSummary, type Language } from "../catalog/cards.ts";
import type { Prompt } from "./api.ts";
import { onField, placeLabel } from "./zones.ts";

// O que todas as telas de pergunta usam: a carta da pergunta, o nome dela e o botão.

export type Answer = (response: Record<string, unknown>) => void;

export type PromptCard = {
  code: number;
  controller: number;
  location: number;
  sequence: number;
  // Só nas perguntas que trazem a posição (escolha de cartas, corrente...).
  position?: number;
  description?: number;
  text?: string | null;
};

export type PromptProps = {
  prompt: Prompt;
  you: number;
  cards: Map<number, CardSummary>;
  language: Language;
  pending: boolean;
  onAnswer: Answer;
  // Mostra o detalhe da carta (o painel da esquerda no computador, a janela no celular).
  onCard?: (code: number) => void;
};

// "Mago Negro (mão)", "Carta escondida (mão do oponente)" ou "Carta virada (zona de monstro
// do oponente, 2ª da esquerda)": no campo vai a zona, para não haver duas escolhas iguais.
export function cardLabel(
  card: PromptCard,
  props: Pick<PromptProps, "you" | "cards" | "language">,
) {
  const name = cardName(card, props);
  const place = placeLabel(card, props.you);
  return place ? `${name} (${place})` : name;
}

// Só o nome: o da carta, ou "Carta virada" e "Carta escondida" quando o jogador não a vê.
export function cardName(card: PromptCard, props: Pick<PromptProps, "cards" | "language">) {
  if (card.code === 0) return onField(card) ? "Carta virada" : "Carta escondida";
  const data = props.cards.get(card.code);
  return data ? displayName(data, props.language) : `Carta ${card.code}`;
}

// A miniatura da carta na lista de escolha (o verso, quando o jogador não a vê).
export function CardThumb(props: { card: PromptCard; cards: Map<number, CardSummary> }) {
  const image = props.cards.get(props.card.code)?.image;
  if (props.card.code === 0 || image === undefined) {
    return <span className="pick-thumb back" aria-hidden="true" />;
  }
  return (
    <img
      className="pick-thumb"
      src={imageUrl(image, "p")}
      alt=""
      width={28}
      height={41}
      decoding="async"
    />
  );
}

export const list = (prompt: Prompt, key: string) =>
  (prompt[key] as PromptCard[] | undefined) ?? [];

export function Choice(props: {
  label: string;
  detail?: string | null;
  disabled?: boolean;
  onClick: () => void;
}) {
  return (
    <button type="button" disabled={props.disabled} onClick={props.onClick}>
      {props.label}
      {props.detail && <span className="choice-detail">{props.detail}</span>}
    </button>
  );
}
