// Onde a carta ou a zona está, do jeito que a pessoa vê a mesa. A contagem vai da esquerda
// para a direita; as zonas do oponente são espelhadas (a zona 1 dele fica à sua direita).
// Assim duas cartas iguais, ou duas viradas, nunca ficam com o mesmo nome na escolha.

const MZONE = 0x04;
const SZONE = 0x08;
const FACE_DOWN = 0x2 | 0x8;

const PILES: Record<number, string> = {
  1: "deck",
  2: "mão",
  16: "cemitério",
  32: "banidas",
  64: "Extra",
};

export type Spot = { controller: number; location: number; sequence: number; position?: number };

export const onField = (spot: Spot) => spot.location === MZONE || spot.location === SZONE;

export const isFaceDown = (spot: Spot) => (Number(spot.position) & FACE_DOWN) !== 0;

// "sua zona de monstro, 3ª da esquerda" ou "zona de campo do oponente".
export function zoneName(location: number, sequence: number, mine: boolean) {
  if (location === SZONE && sequence === 5) {
    return mine ? "sua zona de campo" : "zona de campo do oponente";
  }
  const row = location === MZONE ? "zona de monstro" : "zona de magia e armadilha";
  const column = mine ? sequence + 1 : 5 - sequence;
  return `${mine ? `sua ${row}` : `${row} do oponente`}, ${column}ª da esquerda`;
}

// O que vai entre parênteses depois do nome: a zona (e se a carta sua está virada) ou a
// pilha. Lugar desconhecido fica sem parênteses.
export function placeLabel(spot: Spot, you: number) {
  const mine = spot.controller === you;
  if (onField(spot)) {
    const zone = zoneName(spot.location, spot.sequence, mine);
    return mine && isFaceDown(spot) ? `${zone}, virada para baixo` : zone;
  }
  const pile = PILES[spot.location];
  if (!pile) return undefined;
  return mine ? pile : `${pile} do oponente`;
}
