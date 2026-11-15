import type { Hand } from "./api.ts";

// Pedra, papel e tesoura de quem começa (GXP-81). As mesmas regras do backend
// (Rooms::Opening): cada mão e a que ela vence.
export const HANDS: { hand: Hand; label: string; icon: string }[] = [
  { hand: "rock", label: "Pedra", icon: "✊" },
  { hand: "paper", label: "Papel", icon: "✋" },
  { hand: "scissors", label: "Tesoura", icon: "✌️" },
];

const BEATS: Record<Hand, Hand> = { rock: "scissors", paper: "rock", scissors: "paper" };

export const handName = (hand: Hand) =>
  HANDS.find((item) => item.hand === hand)!.label.toLowerCase();

// A rodada que acabou, do ponto de vista de quem lê.
export function roundText(last: Record<string, Hand>, mySeat: number, other: string) {
  const mine = last[String(mySeat)];
  const theirs = Object.entries(last).find(([seat]) => seat !== String(mySeat))?.[1];
  if (!mine || !theirs) return "";
  if (mine === theirs) return `Empate: os dois tiraram ${handName(mine)}. De novo!`;

  const winner = BEATS[mine] === theirs ? "você ganhou" : `${other} ganhou`;
  return `Você tirou ${handName(mine)} e ${other}, ${handName(theirs)}: ${winner}.`;
}
