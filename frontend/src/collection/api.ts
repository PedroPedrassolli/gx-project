import { useQuery, useQueryClient } from "@tanstack/react-query";
import { request } from "../api.ts";

// Coleção do jogador pela API (escopo 3.2): as cartas, com quantidade e data de obtenção,
// e quanto do pool e de cada pacote ele já tem.
export type Progress = { owned: number; cards: number; percent: number };
export type Collection = {
  // new: a carta ganha na loja ou numa missão que o jogador ainda não viu no baú (GXP-42).
  data: { card_id: number; quantity: number; obtained_at: string; new: boolean }[];
  meta: { total: Progress; packs: (Progress & { id: number })[] };
};

export const collectionKey = ["collection"];

// Marca como vistas essas cartas (sem a lista, todas). A tela muda na hora; se o servidor
// recusar, a coleção é buscada de novo.
export function useMarkSeen() {
  const client = useQueryClient();
  return (cardIds?: number[]) => {
    client.setQueryData<Collection>(collectionKey, (old) =>
      old
        ? {
            ...old,
            data: old.data.map((row) =>
              !cardIds || cardIds.includes(row.card_id) ? { ...row, new: false } : row,
            ),
          }
        : old,
    );
    request("POST", "/api/collection/seen", cardIds ? { card_ids: cardIds } : {}).catch(() =>
      client.invalidateQueries({ queryKey: collectionKey }),
    );
  };
}

export function useCollection(enabled: boolean) {
  return useQuery({
    queryKey: collectionKey,
    queryFn: () => request<Collection>("GET", "/api/collection"),
    enabled,
  });
}
