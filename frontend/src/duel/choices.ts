import type { Prompt } from "./api.ts";

// Regras das escolhas de cartas, iguais às que a engine confere (playerop.cpp): a tela só
// libera o "Confirmar" quando a engine vai aceitar.

export type ChoiceCard = {
  code: number;
  controller: number;
  location: number;
  sequence: number;
};

const cardsOf = (prompt: Prompt, key: string) => (prompt[key] as ChoiceCard[] | undefined) ?? [];

// As cartas escolhidas, pelos índices da lista "cards".
const pickedCards = (prompt: Prompt, chosen: number[]) =>
  chosen.flatMap((index) => cardsOf(prompt, "cards")[index] ?? []);

// Lista vazia não vale: o servidor só aceita escolha com carta (sem carta é "Cancelar").
export function canConfirm(prompt: Prompt, chosen: number[]) {
  const picked = pickedCards(prompt, chosen);
  if (picked.length === 0) return false;
  return picked.length >= Number(prompt.min) && picked.length <= Number(prompt.max);
}

// Quanto já foi escolhido, para mostrar ao lado do "Confirmar".
export function progress(prompt: Prompt, chosen: number[]) {
  const picked = pickedCards(prompt, chosen);
  const min = Number(prompt.min);
  const max = Number(prompt.max);
  return min === max
    ? `Escolhidas: ${picked.length} de ${max}`
    : `Escolhidas: ${picked.length} (de ${min} a ${max})`;
}
