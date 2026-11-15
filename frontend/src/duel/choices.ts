import type { Prompt } from "./api.ts";

// Regras das escolhas de cartas, iguais às que a engine confere (playerop.cpp): a tela só
// libera o "Confirmar" quando a engine vai aceitar.

export type ChoiceCard = {
  code: number;
  controller: number;
  location: number;
  sequence: number;
  release_param?: number;
  sum?: number;
};

const cardsOf = (prompt: Prompt, key: string) => (prompt[key] as ChoiceCard[] | undefined) ?? [];

// As cartas escolhidas, pelos índices da lista "cards".
const pickedCards = (prompt: Prompt, chosen: number[]) =>
  chosen.flatMap((index) => cardsOf(prompt, "cards")[index] ?? []);

// Um monstro pode valer dois tributos (release_param).
const tributes = (cards: ChoiceCard[]) =>
  cards.reduce((total, card) => total + (card.release_param ?? 1), 0);

// Na soma entram as obrigatórias ("must") e as escolhidas.
const sumsOf = (prompt: Prompt, cards: ChoiceCard[]) =>
  [...cardsOf(prompt, "must"), ...cards].map((card) => card.sum ?? 0);

// O "sum" de cada carta traz dois valores: o normal (16 bits de baixo) e outro que a carta
// também pode valer (16 bits de cima, zero quando não há).
export const sumValues = (sum: number): [number, number] => [sum & 0xffff, sum >>> 16];

// Soma exata: dá para chegar ao total usando um dos dois valores de cada carta.
export function exactSum(sums: number[], total: number, index = 0): boolean {
  if (total <= 0 || index === sums.length) return false;
  const [normal, other] = sumValues(sums[index] ?? 0);
  if (index === sums.length - 1) return total === normal || total === other;
  return (
    (total > normal && exactSum(sums, total - normal, index + 1)) ||
    (other > 0 && total > other && exactSum(sums, total - other, index + 1))
  );
}

// Soma de "pelo menos": chega ao total, e sem a menor carta já não chegaria (nada sobra).
export function atLeastSum(sums: number[], total: number) {
  let lowTotal = 0;
  let highTotal = 0;
  let lowest = Infinity;
  for (const sum of sums) {
    const [normal, other] = sumValues(sum);
    const low = other > 0 && other < normal ? other : normal;
    lowTotal += low;
    highTotal += Math.max(normal, other);
    lowest = Math.min(lowest, low);
  }
  return highTotal >= total && lowTotal - lowest < total;
}

// Lista vazia não vale: o servidor só aceita escolha com carta (sem carta é "Cancelar").
export function canConfirm(prompt: Prompt, chosen: number[]) {
  const picked = pickedCards(prompt, chosen);
  const min = Number(prompt.min);
  const max = Number(prompt.max);
  if (picked.length === 0) return false;
  switch (prompt.type) {
    case "select_tribute":
      return picked.length <= max && tributes(picked) >= min;
    case "select_sum": {
      const sums = sumsOf(prompt, picked);
      const total = Number(prompt.acc);
      // select_max: soma exata, com min a max cartas; sem ele, soma de "pelo menos".
      if (!prompt.select_max) return atLeastSum(sums, total);
      return picked.length >= min && picked.length <= max && exactSum(sums, total);
    }
    default:
      return picked.length >= min && picked.length <= max;
  }
}

// Quanto já foi escolhido, para mostrar ao lado do "Confirmar".
export function progress(prompt: Prompt, chosen: number[]) {
  const picked = pickedCards(prompt, chosen);
  const min = Number(prompt.min);
  const max = Number(prompt.max);
  switch (prompt.type) {
    case "select_tribute":
      return `Tributos: ${tributes(picked)} de ${min}`;
    case "select_sum": {
      const total = sumsOf(prompt, picked).reduce((sum, value) => sum + sumValues(value)[0], 0);
      return prompt.select_max
        ? `Total: ${total} de ${Number(prompt.acc)}`
        : `Total: ${total} de pelo menos ${Number(prompt.acc)}`;
    }
    default:
      return min === max
        ? `Escolhidas: ${picked.length} de ${max}`
        : `Escolhidas: ${picked.length} (de ${min} a ${max})`;
  }
}

// A resposta da ordem: para cada carta, a posição em que ela fica (0 é a primeira).
export const sortOrder = (taps: number[], count: number) =>
  Array.from({ length: count }, (_, card) => taps.indexOf(card));
