import { useQuery } from "@tanstack/react-query";
import { request } from "../api.ts";
import type { DeckRow } from "./deck.ts";

// Decks pela API (ADR 0009). Toda resposta com um deck traz se ele é válido e os erros.
export type DeckSummary = {
  id: number;
  name: string;
  updated_at: string;
  counts: { main: number; extra: number; side: number };
};
export type Deck = {
  id: number;
  name: string;
  updated_at: string;
  cards: DeckRow[];
  valid: boolean;
  errors: string[];
};

export function useDecks(enabled: boolean) {
  return useQuery({
    queryKey: ["decks"],
    queryFn: async () => (await request<{ data: DeckSummary[] }>("GET", "/api/decks")).data,
    enabled,
  });
}

export function useDeck(id: number) {
  return useQuery({
    queryKey: ["deck", id],
    queryFn: async () => (await request<{ data: Deck }>("GET", `/api/decks/${id}`)).data,
    retry: false,
  });
}
