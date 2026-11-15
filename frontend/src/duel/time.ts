// "1:05" a partir de milissegundos, arredondando para cima e sem ficar negativo.
export function clock(ms: number) {
  const seconds = Math.max(0, Math.ceil(ms / 1000));
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
}
