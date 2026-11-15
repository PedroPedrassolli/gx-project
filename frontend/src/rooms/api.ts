import { useQuery } from "@tanstack/react-query";
import { request } from "../api.ts";
import { POLL_MS, type RealtimeMode } from "../realtime/useRealtime.ts";

// Salas pela API (ADR 0010). O deck escolhido só vem para o dono dele (deck_id).
export type RoomPlayer = {
  seat: number;
  user_id: number;
  nickname: string;
  ready: boolean;
  deck_chosen: boolean;
  deck_id?: number;
};

export type Hand = "rock" | "paper" | "scissors";

// Com todos prontos, o pedra, papel e tesoura de quem começa (GXP-81). A mão do outro só vem
// quando todos escolheram (last).
export type Opening = {
  hand: Hand | null;
  chosen: number[];
  last: Record<string, Hand> | null;
  chooser_seat: number | null;
};

export type Room = {
  code: string;
  public: boolean;
  mode: string;
  best_of: number;
  banlist: boolean;
  destiny_draw: boolean;
  decision_seconds: number | null; // null: sem limite
  duel_minutes: number | null;
  status: "waiting" | "dueling";
  owner_id: number;
  seats: number;
  players: RoomPlayer[];
  match_id?: number; // em duelo: a partida
  opening?: Opening;
};

export type RoomFlags = { public: boolean; banlist: boolean; destiny_draw: boolean };

export type RoomOptions = RoomFlags & Pick<Room, "decision_seconds" | "duel_minutes">;

export const roomKey = (code: string) => ["room", code];

// Ao vivo, a sala muda pelos avisos (room.updated) e só confere de vez em quando; sem
// tempo real, consulta a cada POLL_MS.
export function useRoom(code: string, mode: RealtimeMode, enabled: boolean) {
  return useQuery({
    queryKey: roomKey(code),
    queryFn: async () => (await request<{ data: Room }>("GET", `/api/rooms/${code}`)).data,
    refetchInterval: mode === "live" ? 30_000 : POLL_MS,
    retry: false,
    enabled,
  });
}

export const roomAction = async (code: string, action: string, body?: unknown) =>
  (await request<{ data: Room } | undefined>("POST", `/api/rooms/${code}/${action}`, body))?.data;
