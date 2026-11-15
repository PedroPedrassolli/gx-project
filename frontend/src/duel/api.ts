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

// O que aconteceu no duelo (Duel::Events), numerado, sem o que este lado não vê.
export type Place = {
  controller: number;
  location: number;
  sequence: number;
  position: number;
  code?: number;
};
export type DuelEvent = { id: number; type: string } & Record<string, unknown>;

// Um elo da corrente aberta, com o texto do efeito quando a carta tem.
export type ChainLink = Place & {
  code: number;
  link: number;
  description?: number;
  text?: string | null;
  negated?: boolean;
};

export type View = {
  you: number;
  turn: number;
  turn_team: number;
  phase?: "draw" | "standby" | "main1" | "battle" | "main2" | "end";
  sides: [Side, Side];
  waiting_for?: number;
  prompt?: Prompt;
  events?: DuelEvent[];
  chain?: ChainLink[];
};

export type MatchState = {
  id: number;
  status: "dueling" | "finished";
  winner_team: number | null;
  // Por que acabou: o próprio duelo, desistência, tempo da resposta ou limite do duelo.
  finish_reason?: "duel" | "surrender" | "timeout" | "time_limit" | null;
  room_code?: string | null;
  // O relógio (escopo 3.7): até quando a pergunta da vez vale, o banco do turno e o fim.
  deadline_at?: string | null;
  turn_time_left?: number;
  ends_at?: string | null; // null: duelo sem limite de tempo
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
    // Com o prazo vencido, consulta logo: é a consulta que encerra a partida no servidor.
    refetchInterval: (query) => {
      const deadline = query.state.data?.deadline_at;
      if (deadline && Date.parse(deadline) < Date.now()) return POLL_MS;
      return mode === "live" ? 10_000 : POLL_MS;
    },
    retry: false,
    enabled,
  });
}

export const surrender = async (id: string) =>
  (await request<{ data: MatchState }>("POST", `/api/matches/${id}/surrender`)).data;

export const respond = async (id: string, seq: number, response: Record<string, unknown>) =>
  (await request<{ data: MatchState }>("POST", `/api/matches/${id}/responses`, { seq, response }))
    .data;
