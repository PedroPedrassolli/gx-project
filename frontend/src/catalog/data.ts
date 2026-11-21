import { useEffect } from "react";
import { queryOptions, useQuery, useQueryClient } from "@tanstack/react-query";
import { preconnect } from "react-dom";
import { request } from "../api.ts";
import { IMAGES_SITE, type CardDetail, type CardSummary, type Pack } from "./cards.ts";

// Dados do catálogo pela API (ADR 0007), guardados pelo TanStack Query: o catálogo, a
// coleção e o Deck Edit usam as mesmas cartas sem buscar de novo.
const HOUR = 60 * 60 * 1000;

async function data<T>(path: string): Promise<T> {
  return (await request<{ data: T }>("GET", path)).data;
}

// Os índices saem uma vez por carga, não a cada tela: a carta pelo id (coleção e decks), a
// carta pelo código da engine (a mesa só sabe o código) e o nome de cada pacote (o detalhe
// da carta mostra onde ela sai). A sala busca o catálogo antes de o duelo abrir.
export const catalogQuery = queryOptions({
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

// Toda página que usa o catálogo mostra imagens das cartas: a conexão com o site delas abre
// já no começo, enquanto a lista ainda chega, e as primeiras imagens aparecem uns 0,4 s
// antes. O React põe o <link rel="preconnect"> uma vez só, por mais que a página chame.
export function useCatalog() {
  preconnect(IMAGES_SITE);
  return useQuery(catalogQuery);
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

const cardDetailQuery = (id: number) =>
  queryOptions({
    queryKey: ["card", id],
    queryFn: () => data<CardDetail>(`/api/cards/${id}`),
    retry: false,
    staleTime: HOUR,
  });

export function useCardDetail(id: number) {
  return useQuery({ ...cardDetailQuery(id), enabled: id > 0 });
}

// Busca em segundo plano o detalhe das cartas que podem ser tocadas (as da mesa), para o
// texto já estar aqui no toque (GXP-107). O que já veio não é pedido de novo, e o pouco de
// espera deixa a jogada que trouxe as cartas terminar primeiro.
export function usePrefetchCardDetails(ids: number[]) {
  const client = useQueryClient();
  const key = ids.join(",");
  useEffect(() => {
    if (!key) return;
    const timer = setTimeout(() => {
      for (const id of key.split(",")) void client.prefetchQuery(cardDetailQuery(Number(id)));
    }, 300);
    return () => clearTimeout(timer);
  }, [client, key]);
}
