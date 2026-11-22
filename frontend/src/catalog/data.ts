import { useEffect } from "react";
import { queryOptions, useQuery, useQueryClient, type QueryClient } from "@tanstack/react-query";
import { preconnect } from "react-dom";
import { request } from "../api.ts";
import { IMAGES_SITE, type CardDetail, type CardSummary, type Pack } from "./cards.ts";
import { readStored, writeStored } from "./stored.ts";

// Dados do catálogo pela API (ADR 0007), guardados pelo TanStack Query: o catálogo, a
// coleção e o Deck Edit usam as mesmas cartas sem buscar de novo.
const HOUR = 60 * 60 * 1000;

async function data<T>(path: string): Promise<T> {
  return (await request<{ data: T }>("GET", path)).data;
}

// As cópias guardadas no navegador (GXP-122).
const STORED_CATALOG = "/dados/catalogo.json";
const STORED_DETAILS = "/dados/detalhes.json";

// Os índices saem uma vez por carga, não a cada tela: a carta pelo id (coleção e decks), a
// carta pelo código da engine (a mesa só sabe o código) e o nome de cada pacote (o detalhe
// da carta mostra onde ela sai). A sala busca o catálogo antes de o duelo abrir.
function buildCatalog(cards: CardSummary[], packs: Pack[]) {
  const byId = new Map(cards.map((card) => [card.id, card]));
  const byCode = new Map<number, CardSummary>();
  for (const card of cards) if (card.code !== undefined) byCode.set(card.code, card);
  const packNames = new Map(packs.map((pack) => [pack.id, pack.name]));
  return { cards, packs, byId, byCode, packNames };
}

// gcTime infinito: o catálogo fica na memória a visita inteira, mesmo nas telas que não o usam.
export const catalogQuery = queryOptions({
  queryKey: ["catalog"],
  queryFn: async () => {
    const [cards, packs] = await Promise.all([
      data<CardSummary[]>("/api/cards"),
      data<Pack[]>("/api/packs"),
    ]);
    writeStored(STORED_CATALOG, { cards, packs });
    return buildCatalog(cards, packs);
  },
  staleTime: HOUR,
  gcTime: Infinity,
});

// Toda página que usa o catálogo mostra imagens das cartas: a conexão com o site delas abre
// já no começo, enquanto a lista ainda chega, e as primeiras imagens aparecem uns 0,4 s
// antes. O React põe o <link rel="preconnect"> uma vez só, por mais que a página chame.
export function useCatalog() {
  preconnect(IMAGES_SITE);
  const client = useQueryClient();
  const catalog = useQuery(catalogQuery);
  // Com o catálogo na tela, o detalhe de todas as cartas vem logo depois, sem disputar a rede
  // com ele (GXP-121): quando o jogador tocar numa carta, o texto já está aqui.
  const ready = catalog.isSuccess;
  useEffect(() => {
    if (!ready) return;
    const timer = setTimeout(() => void client.prefetchQuery(detailsQuery), 1000);
    return () => clearTimeout(timer);
  }, [client, ready]);
  return catalog;
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

// O que só o detalhe traz (textos, pacotes, fonte); com o resumo do catálogo, vira a carta
// inteira.
type CardExtra = Omit<CardDetail, keyof CardSummary>;

function buildDetails(extras: Record<string, CardExtra>) {
  return new Map(Object.entries(extras).map(([id, extra]) => [Number(id), extra]));
}

// O detalhe de todas as cartas num pedido só (GXP-121), com cache na CDN como o catálogo.
export const detailsQuery = queryOptions({
  queryKey: ["card-details"],
  queryFn: async () => {
    const extras = await data<Record<string, CardExtra>>("/api/cards/details");
    writeStored(STORED_DETAILS, extras);
    return buildDetails(extras);
  },
  staleTime: HOUR,
  gcTime: Infinity,
  retry: 3,
});

// Na abertura do site, a cópia guardada vira o catálogo e os textos da tela, marcados como
// velhos (updatedAt 0): quem usa o catálogo já busca a versão nova, em segundo plano. Se a
// resposta do servidor chegar antes da cópia, a cópia fica de fora.
export async function restoreStoredCatalog(client: QueryClient) {
  const [catalog, details] = await Promise.all([
    readStored<{ cards: CardSummary[]; packs: Pack[] }>(STORED_CATALOG),
    readStored<Record<string, CardExtra>>(STORED_DETAILS),
  ]);
  if (catalog && !client.getQueryData(catalogQuery.queryKey)) {
    const restored = buildCatalog(catalog.cards, catalog.packs);
    client.setQueryData(catalogQuery.queryKey, restored, { updatedAt: 0 });
  }
  if (details && !client.getQueryData(detailsQuery.queryKey)) {
    client.setQueryData(detailsQuery.queryKey, buildDetails(details), { updatedAt: 0 });
  }
}

// A carta sozinha: o plano B enquanto o pedido de todas não chegou (a primeira visita).
const cardDetailQuery = (id: number) =>
  queryOptions({
    queryKey: ["card", id],
    queryFn: () => data<CardDetail>(`/api/cards/${id}`),
    retry: 2,
    staleTime: HOUR,
  });

// A carta inteira: o resumo do catálogo com o detalhe de todas; sem ele, o pedido da carta
// sozinha. Só falha quando os dois falharam.
export function useCardDetail(id: number) {
  const summary = useQuery(catalogQuery).data?.byId.get(id);
  const all = useQuery(detailsQuery);
  const extra = all.data?.get(id);
  const single = useQuery({ ...cardDetailQuery(id), enabled: id > 0 && !(summary && extra) });
  const data: CardDetail | undefined = summary && extra ? { ...summary, ...extra } : single.data;
  return { data, isError: !data && single.isError && !all.isPending };
}
