import { displayName, type CardSummary, type Language } from "../catalog/cards.ts";
import type { Prompt } from "./api.ts";

// O que todas as telas de pergunta usam: a carta da pergunta, o nome dela e o botão.

export type Answer = (response: Record<string, unknown>) => void;

export type PromptCard = {
  code: number;
  controller: number;
  location: number;
  sequence: number;
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
};

const LOCATIONS: Record<number, string> = {
  1: "deck",
  2: "mão",
  4: "campo",
  8: "campo",
  16: "cemitério",
  32: "banidas",
  64: "Extra",
};

// "Mago Negro (mão)" ou "Carta escondida (mão do oponente)".
export function cardLabel(
  card: PromptCard,
  props: Pick<PromptProps, "you" | "cards" | "language">,
) {
  const data = props.cards.get(card.code);
  const name =
    card.code === 0
      ? "Carta escondida"
      : data
        ? displayName(data, props.language)
        : `Carta ${card.code}`;
  const place = LOCATIONS[card.location];
  if (!place) return name;
  return `${name} (${place}${card.controller === props.you ? "" : " do oponente"})`;
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
