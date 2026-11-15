import { useState, type FormEvent } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { Link, useLocation, useNavigate } from "react-router";
import { request } from "../api.ts";
import { useSession } from "../account/session.ts";
import { SignInFirst } from "../PageNotice.tsx";
import { usePageTitle } from "../pageTitle.ts";
import type { Room, RoomFlags, RoomOptions } from "./api.ts";
import {
  DECISION_SECONDS,
  DUEL_MINUTES,
  decisionChip,
  decisionText,
  duelChip,
  fromSelect,
} from "./times.ts";

type RoomSummary = {
  code: string;
  owner: string;
  players: number;
  seats: number;
  banlist: boolean;
  destiny_draw: boolean;
  decision_seconds: number | null;
  duel_minutes: number | null;
};

const OPTIONS: { key: keyof RoomFlags; label: string }[] = [
  { key: "public", label: "Pública" },
  { key: "banlist", label: "Banlist" },
  { key: "destiny_draw", label: "Destiny Draw" },
];

// Salas (escopo 4): criar uma, entrar com o código que um amigo mandou ou escolher uma das
// públicas. A lista confere de novo a cada 10 s.
export function RoomsPage() {
  usePageTitle("Salas");
  const session = useSession();
  const user = session.data?.user;
  const navigate = useNavigate();
  const notice = (useLocation().state as { notice?: string } | null)?.notice;
  const [options, setOptions] = useState<RoomOptions>({
    public: true,
    banlist: true,
    destiny_draw: true,
    decision_seconds: 90,
    duel_minutes: 60,
  });
  const [code, setCode] = useState("");
  const rooms = useQuery({
    queryKey: ["rooms"],
    queryFn: async () => (await request<{ data: RoomSummary[] }>("GET", "/api/rooms")).data,
    refetchInterval: 10_000,
    enabled: Boolean(user),
  });
  const create = useMutation({
    mutationFn: async () => (await request<{ data: Room }>("POST", "/api/rooms", options)).data,
    onSuccess: (room) => navigate(`/salas/${room.code}`),
  });

  function enter(event: FormEvent) {
    event.preventDefault();
    navigate(`/salas/${code.trim().toUpperCase()}`);
  }

  if (session.isSuccess && !user) {
    return <SignInFirst title="Salas" reason="para jogar" />;
  }

  return (
    <main className="page rooms-page">
      <h1>Salas</h1>
      {notice && <p role="status">{notice}</p>}

      <section aria-labelledby="create-title">
        <h2 id="create-title">Criar sala</h2>
        <fieldset className="room-create">
          <legend>Opções</legend>
          {OPTIONS.map(({ key, label }) => (
            <label key={key} className="choice">
              <input
                type="checkbox"
                checked={options[key]}
                onChange={(event) => setOptions({ ...options, [key]: event.target.checked })}
              />
              {label}
            </label>
          ))}
        </fieldset>
        <div className="room-times">
          <div className="field">
            <label htmlFor="room-decision">Tempo de resposta</label>
            <select
              id="room-decision"
              value={options.decision_seconds ?? ""}
              onChange={(event) =>
                setOptions({ ...options, decision_seconds: fromSelect(event.target.value) })
              }
            >
              {DECISION_SECONDS.map((seconds) => (
                <option key={seconds} value={seconds}>
                  {decisionText(seconds)}
                </option>
              ))}
              <option value="">Sem limite</option>
            </select>
          </div>
          <div className="field">
            <label htmlFor="room-duel">Tempo do duelo</label>
            <select
              id="room-duel"
              value={options.duel_minutes ?? ""}
              onChange={(event) =>
                setOptions({ ...options, duel_minutes: fromSelect(event.target.value) })
              }
            >
              {DUEL_MINUTES.map((minutes) => (
                <option key={minutes} value={minutes}>
                  {minutes} min
                </option>
              ))}
              <option value="">Sem limite</option>
            </select>
          </div>
        </div>
        <p className="hint">
          A pública aparece em “Salas abertas” para qualquer um entrar; a privada, só com o código.
          A banlist é a do jogo. Quem deixa o tempo de resposta passar perde o duelo; quando o tempo
          do duelo acaba, ganha quem tem mais PV.
        </p>
        <p className="actions">
          <button
            type="button"
            className="cta"
            disabled={create.isPending}
            onClick={() => create.mutate()}
          >
            Criar sala
          </button>
          {create.error && (
            <span role="alert" className="form-error">
              {create.error.message}
            </span>
          )}
        </p>
      </section>

      <section aria-labelledby="code-title">
        <h2 id="code-title">Entrar com o código</h2>
        <form className="code-form" onSubmit={enter}>
          <label htmlFor="room-code">Código da sala</label>
          <input
            id="room-code"
            type="text"
            required
            minLength={6}
            maxLength={6}
            autoCapitalize="characters"
            autoComplete="off"
            spellCheck={false}
            value={code}
            onChange={(event) => setCode(event.target.value)}
          />
          <button type="submit">Ir para a sala</button>
        </form>
      </section>

      <section aria-labelledby="open-title">
        <h2 id="open-title">Salas abertas</h2>
        {rooms.data && rooms.data.length === 0 && (
          <p>Nenhuma sala aberta agora. Crie uma e mande o código para um amigo.</p>
        )}
        <ul className="deck-list">
          {rooms.data?.map((room) => (
            <li key={room.code}>
              <Link to={`/salas/${room.code}`}>Sala de {room.owner}</Link>
              <span className="deck-counts">
                <span>
                  {room.players} de {room.seats}
                </span>{" "}
                <span>{room.banlist ? "Banlist do jogo" : "Sem banlist"}</span>{" "}
                <span>{room.destiny_draw ? "Com Destiny Draw" : "Sem Destiny Draw"}</span>{" "}
                <span>{decisionChip(room.decision_seconds)}</span>{" "}
                <span>{duelChip(room.duel_minutes)}</span>
              </span>
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}
