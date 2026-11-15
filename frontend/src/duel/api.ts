import { useQuery } from "@tanstack/react-query";
import { request } from "../api.ts";
import { POLL_MS, type RealtimeMode } from "../realtime/useRealtime.ts";

// A partida pela API (ADR 0011). A mesa vem pronta do servidor, já sem o que o jogador não
// pode ver: a tela só desenha. Carta sem "code" está virada para baixo (ou é do outro).
export type FieldCard = {
  code?: number;
  face_down: boolean;
  defense: boolean;
  atk?: number;
  def?: number;
};

// Na própria mão, "public" marca a carta revelada por um efeito, que o outro também vê.
export type HandCard = { code?: number; hidden?: boolean; public?: boolean };

export type Side = {
  team: number;
  lp: number;
  deck: number;
  extra: number;
  hand: HandCard[];
  monsters: (FieldCard | null)[];
  spells: (FieldCard | null)[];
  field_spell?: FieldCard;
  grave: HandCard[];
  banished: HandCard[];
  extra_cards?: HandCard[];
};

export type Prompt = { type: string; player: number } & Record<string, unknown>;

export type View = {
  you: number;
  turn: number;
  turn_team: number;
  phase?: "draw" | "standby" | "main1" | "battle" | "main2" | "end";
  sides: [Side, Side];
  waiting_for?: number;
  prompt?: Prompt;
};

export type MatchState = {
  id: number;
  status: "dueling" | "finished";
  winner_team: number | null;
  seq: number;
  you: number;
  players: { team: number; nickname: string }[];
  view: View;
};

export const matchKey = (id: string) => ["match", id];

// Ao vivo, a mesa muda pelos avisos (duel.updated) e confere de vez em quando; sem tempo
// real, consulta a cada POLL_MS.
export function useMatch(id: string, mode: RealtimeMode, enabled: boolean) {
  return useQuery({
    queryKey: matchKey(id),
    queryFn: async () => (await request<{ data: MatchState }>("GET", `/api/matches/${id}`)).data,
    refetchInterval: mode === "live" ? 10_000 : POLL_MS,
    retry: false,
    enabled,
  });
}

export const respond = async (id: string, seq: number, response: Record<string, unknown>) =>
  (await request<{ data: MatchState }>("POST", `/api/matches/${id}/responses`, { seq, response }))
    .data;
