// Fases do projeto (escopo, seção 8). "done" muda à mão quando a fase fecha.
export type Phase = { code: string; name: string; done: boolean };

export const PHASES: Phase[] = [
  { code: "F0", name: "Fundação e dados", done: true },
  { code: "F1", name: "Catálogo de cartas", done: true },
  { code: "F2", name: "Contas e montagem de decks", done: true },
  { code: "F3", name: "Duelo 1x1 em sala", done: true },
  { code: "F4", name: "Economia e loja", done: true },
  { code: "F5", name: "Duelos contra personagens", done: true },
  { code: "F6", name: "Front novo", done: false },
  { code: "F7", name: "Social e acabamento", done: false },
];

// Primeira fase ainda aberta; undefined quando todas terminaram.
export function currentPhase(phases: Phase[]): Phase | undefined {
  return phases.find((phase) => !phase.done);
}
