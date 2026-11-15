import type { Prompt } from "./api.ts";

// O que os anúncios da engine precisam: as zonas livres.

export type Zone = { player: number; location: number; sequence: number; label: string };

const MZONE = 0x04;
const SZONE = 0x08;

function zoneLabel(location: number, sequence: number, mine: boolean) {
  const name =
    location === MZONE
      ? `zona de monstro ${sequence + 1}`
      : sequence === 5
        ? "zona de campo"
        : `zona de magia e armadilha ${sequence + 1}`;
  return mine ? `Sua ${name}` : `${name[0]?.toUpperCase()}${name.slice(1)} do oponente`;
}

// No "flag", bit ligado é zona que não vale. Do lado de quem escolhe: monstros nos bits 0 a
// 4, magias e armadilhas de 8 a 12 e o campo no 13; do outro lado, 16 bits acima.
export function freeZones(prompt: Prompt): Zone[] {
  const flag = Number(prompt.flag);
  const zones: Zone[] = [];
  for (const side of [0, 1]) {
    const player = side === 0 ? prompt.player : 1 - prompt.player;
    const groups: [number, number, number][] = [
      [MZONE, 0, 5],
      [SZONE, 8, 6],
    ];
    for (const [location, firstBit, size] of groups) {
      for (let sequence = 0; sequence < size; sequence++) {
        if ((flag & (1 << (firstBit + sequence + 16 * side))) === 0)
          zones.push({
            player,
            location,
            sequence,
            label: zoneLabel(location, sequence, side === 0),
          });
      }
    }
  }
  return zones;
}
