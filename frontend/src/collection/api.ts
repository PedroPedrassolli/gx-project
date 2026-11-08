import { useQuery } from "@tanstack/react-query";
import { request } from "../api.ts";

// Coleção do jogador pela API (escopo 3.2): as cartas, com quantidade e data de obtenção,
// e quanto do pool e de cada pacote ele já tem.
export type Progress = { owned: number; cards: number; percent: number };
export type Collection = {
  data: { card_id: number; quantity: number; obtained_at: string }[];
  meta: { total: Progress; packs: (Progress & { id: number })[] };
};

export function useCollection(enabled: boolean) {
  return useQuery({
    queryKey: ["collection"],
    queryFn: () => request<Collection>("GET", "/api/collection"),
    enabled,
  });
}
