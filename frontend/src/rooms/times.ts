// Os tempos que o dono da sala escolhe (GXP-80). São os mesmos do backend
// (Matches::Clock); null é sem limite.
export const DECISION_SECONDS = [30, 60, 90, 180];
export const DUEL_MINUTES = [20, 40, 60, 90];

// 90 → "1 min 30 s"; 60 → "1 min"; 30 → "30 s".
export function decisionText(seconds: number) {
  const minutes = Math.floor(seconds / 60);
  const rest = seconds % 60;
  return [minutes ? `${minutes} min` : "", rest ? `${rest} s` : ""].filter(Boolean).join(" ");
}

// As fichas da sala e da lista de salas.
export const decisionChip = (seconds: number | null) =>
  seconds === null ? "Resposta sem limite" : `${decisionText(seconds)} por resposta`;

export const duelChip = (minutes: number | null) =>
  minutes === null ? "Duelo sem limite" : `Duelo de ${minutes} min`;

// O valor do <select>: vazio é sem limite.
export const fromSelect = (value: string) => (value === "" ? null : Number(value));
