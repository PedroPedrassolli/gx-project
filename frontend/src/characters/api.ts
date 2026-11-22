import { useQuery } from "@tanstack/react-query";
import { request } from "../api.ts";

// Duelos contra personagens (escopo 3.10; ADR 0013): a lista na ordem de liberar, com o que o
// jogador já venceu, e o começo do duelo.
export type CharacterStatus = "beaten" | "unlocked" | "locked";
export type SignatureCard = { id: number; name: string; name_pt?: string; image?: number };
export type Character = {
  id: string;
  position: number;
  name: string;
  description: string;
  group: { id: string; name: string };
  deck: string; // o nome do deck no jogo de referência
  bonus: number; // DP a mais na vitória
  signature?: SignatureCard; // o prêmio da primeira vitória
  wins: number;
  status: CharacterStatus;
  unlock_hint?: string; // só no bloqueado: quem vencer antes
};
export type Characters = { characters: Character[] };

export const charactersKey = ["characters"];

export function useCharacters(enabled: boolean) {
  return useQuery({
    queryKey: charactersKey,
    queryFn: async () => (await request<{ data: Characters }>("GET", "/api/characters")).data,
    enabled,
  });
}

export async function startDuel(character: string, deckId: string) {
  const body = await request<{ data: { match_id: number } }>(
    "POST",
    `/api/characters/${character}/duels`,
    { deck_id: deckId },
  );
  return body.data.match_id;
}

// Os personagens em grupos (alunos, chefes, lendas), na ordem em que vêm.
export function byGroup(characters: Character[]) {
  const groups: { id: string; name: string; characters: Character[] }[] = [];
  for (const character of characters) {
    const last = groups.at(-1);
    if (last?.id === character.group.id) last.characters.push(character);
    else groups.push({ ...character.group, characters: [character] });
  }
  return groups;
}
