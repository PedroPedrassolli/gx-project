import type { DragEvent } from "react";
import type { Section } from "./deck.ts";

// Arrastar e soltar no desktop (escopo 3.3): do baú para uma seção do deck, e de uma linha
// do deck de volta para o baú (tira uma cópia). Os botões continuam fazendo o mesmo, no
// teclado e no celular.
const CARD = "application/x-gx-carta";
const ROW = "application/x-gx-linha-do-deck";

export function dragCard(event: DragEvent, cardId: number) {
  event.dataTransfer.setData(CARD, String(cardId));
  event.dataTransfer.effectAllowed = "copy";
}

export function dragRow(event: DragEvent, cardId: number, section: Section) {
  event.dataTransfer.setData(ROW, `${cardId}:${section}`);
  event.dataTransfer.effectAllowed = "move";
}

// Para onDragOver: aceita o que vem do baú (into = "deck") ou do deck (into = "baú").
export function allowDrop(event: DragEvent, into: "deck" | "baú") {
  if (event.dataTransfer.types.includes(into === "deck" ? CARD : ROW)) event.preventDefault();
}

export function droppedCard(event: DragEvent): number | null {
  const value = Number(event.dataTransfer.getData(CARD));
  return value > 0 ? value : null;
}

export function droppedRow(event: DragEvent): { cardId: number; section: Section } | null {
  const [cardId, section] = event.dataTransfer.getData(ROW).split(":");
  return cardId && section ? { cardId: Number(cardId), section: section as Section } : null;
}
