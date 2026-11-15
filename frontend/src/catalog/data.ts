import { useQuery } from "@tanstack/react-query";
import { request } from "../api.ts";
import type { CardDetail, CardSummary, Pack } from "./cards.ts";

// Dados do catálogo pela API (ADR 0007), guardados pelo TanStack Query: o catálogo, a
// coleção e o Deck Edit usam as mesmas cartas sem buscar de novo.
const HOUR = 60 * 60 * 1000;

async function data<T>(path: string): Promise<T> {
  return (await request<{ data: T }>("GET", path)).data;
}

// Os índices saem uma vez por carga, não a cada tela: a carta pelo id (coleção e decks), a
// carta pelo código da engine (a mesa só sabe o código) e o nome de cada pacote (o detalhe
// da carta mostra onde ela sai).
export function useCatalog() {
  return useQuery({
    queryKey: ["catalog"],
    queryFn: async () => {
      const [cards, packs] = await Promise.all([
        data<CardSummary[]>("/api/cards"),
        data<Pack[]>("/api/packs"),
      ]);
      const byId = new Map(cards.map((card) => [card.id, card]));
      const byCode = new Map<number, CardSummary>();
      for (const card of cards) if (card.code !== undefined) byCode.set(card.code, card);
      const packNames = new Map(packs.map((pack) => [pack.id, pack.name]));
      return { cards, packs, byId, byCode, packNames };
    },
    staleTime: HOUR,
  });
}

// Enquanto o catálogo carrega: índices vazios, sempre os mesmos.
export const NO_CARDS = new Map<number, CardSummary>();
export const NO_PACKS = new Map<number, string>();

// Raridade de cada carta no pacote escolhido ("" = nenhum pacote).
export function usePackRarities(pack: string) {
  return useQuery({
    queryKey: ["pack", pack],
    queryFn: async () => {
      const cards = await data<CardSummary[]>(`/api/cards?pack=${pack}`);
      return new Map(cards.map((card) => [card.id, card.rarity ?? ""]));
    },
    enabled: pack !== "",
    staleTime: HOUR,
  });
}

export function useCardDetail(id: number) {
  return useQuery({
    queryKey: ["card", id],
    queryFn: () => data<CardDetail>(`/api/cards/${id}`),
    enabled: id > 0,
    retry: false,
    staleTime: HOUR,
  });
}
