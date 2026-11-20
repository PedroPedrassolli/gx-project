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
};

export type Shop = { balance: number; level: number; packs: ShopPack[] };

export type DrawnCard = { id: number; rarity: string; new: boolean };

export const shopKey = ["shop"];

export function useShop(enabled: boolean) {
  return useQuery({
    queryKey: shopKey,
    queryFn: async () => (await request<{ data: Shop }>("GET", "/api/shop")).data,
    enabled,
  });
}

// O código secreto: devolve os nomes dos pacotes que ele libera.
export async function redeemCode(code: string) {
  const response = await request<{ data: { packs: string[] } }>("POST", "/api/shop/codes", {
    code,
  });
  return response.data.packs;
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
