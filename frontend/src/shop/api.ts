import { useQuery } from "@tanstack/react-query";
import { request } from "../api.ts";

// A loja (escopo 3.4; GXP-86): a prateleira do jogador e a compra de pacotes.
export type ShopPack = {
  id: number;
  name: string;
  price: number;
  cards_per_pack: number;
  available: boolean;
  hint: string | null; // como liberar, quando bloqueado
  new: boolean; // liberado e ainda não visto na prateleira
};

export type Shop = { balance: number; level: number; packs: ShopPack[] };

// rare_slot: a carta de raridade aumentada do pacote (a última), que sai rara ou melhor.
export type DrawnCard = { id: number; rarity: string; new: boolean; rare_slot?: boolean };

export const shopKey = ["shop"];

export function useShop(enabled: boolean) {
  return useQuery({
    queryKey: shopKey,
    queryFn: async () => (await request<{ data: Shop }>("GET", "/api/shop")).data,
    enabled,
  });
}

// Os pacotes liberados agora deixam de ser novos. A tela não busca a loja de novo: o destaque
// fica até o jogador sair da página.
export async function markPacksSeen() {
  await request("POST", "/api/shop/seen");
}

// O código secreto: devolve os nomes dos pacotes que ele libera.
export async function redeemCode(code: string) {
  const response = await request<{ data: { packs: string[] } }>("POST", "/api/shop/codes", {
    code,
  });
  return response.data.packs;
}

// O conversor (GXP-90): as cópias que dá para trocar e as cartas que podem sair.
export type Converter = {
  min: number;
  max: number;
  cards: { card_id: number; quantity: number }[];
};

export const converterKey = ["converter"];

export function useConverter(enabled: boolean) {
  return useQuery({
    queryKey: converterKey,
    queryFn: async () => (await request<{ data: Converter }>("GET", "/api/shop/converter")).data,
    enabled,
  });
}

export function useConverterGroup(amount: number, enabled: boolean) {
  return useQuery({
    queryKey: ["converter-group", amount],
    queryFn: async () =>
      (await request<{ data: { cards: number[] } }>("GET", `/api/shop/converter/groups/${amount}`))
        .data.cards,
    enabled,
    staleTime: Infinity, // os grupos são do jogo e não mudam
  });
}

// A chave da conversão, como a da compra: o mesmo pedido mandado duas vezes troca uma vez só.
export async function convertCards(cards: Record<number, number>, key: string) {
  const body = {
    cards: Object.entries(cards).map(([id, quantity]) => ({ id: Number(id), quantity })),
    key,
  };
  const response = await request<{ data: { card_id: number; amount: number; new: boolean } }>(
    "POST",
    "/api/shop/conversions",
    body,
  );
  return response.data;
}

// A chave da compra: a mesma chave devolve a mesma compra (clique duplo, rede que repete).
export async function buyPacks(pack: ShopPack, count: 1 | 10, key: string) {
  const body = { pack_id: pack.id, count, key };
  const response = await request<{ data: { balance: number; openings: DrawnCard[][] } }>(
    "POST",
    "/api/shop/purchases",
    body,
  );
  return response.data;
}
