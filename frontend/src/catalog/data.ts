import { useQuery } from "@tanstack/react-query";
import { request } from "../api.ts";
import type { CardDetail, CardSummary, Pack } from "./cards.ts";

// Dados do catálogo pela API (ADR 0007), guardados pelo TanStack Query: o catálogo, a
// coleção e o Deck Edit usam as mesmas cartas sem buscar de novo.
const HOUR = 60 * 60 * 1000;

async function data<T>(path: string): Promise<T> {
  return (await request<{ data: T }>("GET", path)).data;
}

export function useCatalog() {
  return useQuery({
    queryKey: ["catalog"],
    queryFn: async () => {
      const [cards, packs] = await Promise.all([
        data<CardSummary[]>("/api/cards"),
        data<Pack[]>("/api/packs"),
      ]);
      return { cards, packs };
    },
    staleTime: HOUR,
  });
}

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
