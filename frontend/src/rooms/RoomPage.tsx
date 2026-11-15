import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Link, Navigate, useNavigate, useParams } from "react-router";
import { ApiError } from "../api.ts";
import { useSession } from "../account/session.ts";
import { useDecks } from "../decks/api.ts";
import { PageNotice, SignInFirst } from "../PageNotice.tsx";
import { usePageTitle } from "../pageTitle.ts";
import { useRealtime } from "../realtime/useRealtime.ts";
import { roomAction, roomKey, useRoom, type Room, type RoomPlayer } from "./api.ts";

// Sala de espera (escopo 4, "Salas"): os lugares frente a frente, quem já está pronto e o
// deck de cada um. O duelo começa quando todos estão prontos (GXP-48).
export function RoomPage() {
  const code = (useParams().code ?? "").toUpperCase();
  usePageTitle(`Sala ${code}`);
  const session = useSession();
  const user = session.data?.user;
  const client = useQueryClient();
  const navigate = useNavigate();
  const leaveTo = (notice: string) => navigate("/salas", { state: { notice } });
  const mode = useRealtime(user?.id, (event, data) => {
    // O canal é do jogador: o aviso pode ser de outra sala.
    if ((data as { code?: string } | null)?.code !== code) return;
    if (event === "room.updated") client.setQueryData(roomKey(code), data as Room);
    if (event === "match.started") navigate(`/duelo/${(data as { match_id: number }).match_id}`);
    if (event === "room.closed") leaveTo("A sala fechou: quem criou saiu.");
    if (event === "room.kicked") leaveTo("Quem criou a sala tirou você dela.");
  });
  const room = useRoom(code, mode, Boolean(user));
  const decks = useDecks(Boolean(user));
  const [deckId, setDeckId] = useState("");
  const [copied, setCopied] = useState(false);

  const update = (data: Room | undefined) => data && client.setQueryData(roomKey(code), data);
  const join = useMutation({ mutationFn: () => roomAction(code, "join"), onSuccess: update });
  const ready = useMutation({
    mutationFn: (body: { deck_id?: string; ready: boolean }) => roomAction(code, "ready", body),
    onSuccess: update,
  });
  const kick = useMutation({
    mutationFn: (userId: number) => roomAction(code, "kick", { user_id: userId }),
    onSuccess: () => room.refetch(),
  });
  const leave = useMutation({
    mutationFn: () => roomAction(code, "leave"),
    onSuccess: () => navigate("/salas"),
  });

  if (session.isSuccess && !user) {
    return <SignInFirst title={`Sala ${code}`} reason="para jogar" />;
  }
  if (room.error) {
    return (
      <PageNotice title={`Sala ${code}`}>
        <p role="alert">Não achamos esta sala. Confira o código ou crie outra.</p>
        <p>
          <Link to="/salas">Ver as salas</Link>
        </p>
      </PageNotice>
    );
  }
  if (!room.data || !user) {
    return (
      <PageNotice title={`Sala ${code}`}>
        <p role="status">Carregando a sala…</p>
      </PageNotice>
    );
  }

  const data = room.data;
  // Em duelo (o aviso pode não ter chegado, sem tempo real): vai para a mesa. Só com a sala
  // lida agora: a guardada de antes do duelo levaria de volta à mesa quem acabou de sair do
  // resultado para a revanche.
  if (data.status === "dueling" && data.match_id) {
    if (!room.isFetchedAfterMount) {
      return (
        <PageNotice title={`Sala ${code}`}>
          <p role="status">Carregando a sala…</p>
        </PageNotice>
      );
    }
    return <Navigate to={`/duelo/${data.match_id}`} replace />;
  }
  const me = data.players.find((player) => player.user_id === user.id);
  const owner = data.owner_id === user.id;
  const chosenDeck = deckId || String(me?.deck_id ?? "");
  const deckErrors = ready.error instanceof ApiError ? (ready.error.fields.deck ?? []) : [];

  async function copyCode() {
    await navigator.clipboard.writeText(code);
    setCopied(true);
  }

  return (
    <main className="page room-page">
      <h1>Sala {code}</h1>
      <p className="room-options">
        <span>{data.public ? "Pública" : "Privada"}</span>
        <span>{data.banlist ? "Banlist do jogo" : "Sem banlist"}</span>
        <span>{data.destiny_draw ? "Destiny Draw ligado" : "Destiny Draw desligado"}</span>
        <button type="button" onClick={copyCode}>
          {copied ? "Código copiado" : "Copiar o código"}
        </button>
      </p>

      <ol className="seats" aria-label="Lugares">
        {Array.from({ length: data.seats }, (_, seat) => {
          const player = data.players.find((item) => item.seat === seat);
          return player ? (
            <Seat
              key={seat}
              player={player}
              ownerId={data.owner_id}
              onKick={
                owner && player.user_id !== user.id ? () => kick.mutate(player.user_id) : undefined
              }
            />
          ) : (
            <li key={seat} className="seat empty">
              Vaga livre
            </li>
          );
        })}
      </ol>

      {me ? (
        <section aria-labelledby="my-deck-title" className="my-deck">
          <h2 id="my-deck-title">Seu deck</h2>
          <div className="form-field">
            <label htmlFor="room-deck">Deck</label>
            <select
              id="room-deck"
              value={chosenDeck}
              disabled={me.ready}
              onChange={(event) => setDeckId(event.target.value)}
            >
              <option value="">Escolha um deck</option>
              {decks.data?.map((deck) => (
                <option key={deck.id} value={deck.id}>
                  {deck.name}
                </option>
              ))}
            </select>
          </div>
          <p className="actions">
            <button
              type="button"
              className="cta"
              disabled={ready.isPending || (!me.ready && !chosenDeck)}
              onClick={() => ready.mutate({ deck_id: chosenDeck, ready: !me.ready })}
            >
              {me.ready ? "Não estou pronto" : "Estou pronto"}
            </button>
            <button type="button" disabled={leave.isPending} onClick={() => leave.mutate()}>
              Sair da sala
            </button>
          </p>
          {ready.error && (
            <div role="alert" className="form-error">
              <p>{ready.error.message}</p>
              {deckErrors.length > 0 && (
                <ul>
                  {deckErrors.map((error) => (
                    <li key={error}>{error}</li>
                  ))}
                </ul>
              )}
            </div>
          )}
        </section>
      ) : (
        <p className="actions">
          <button
            type="button"
            className="cta"
            disabled={join.isPending}
            onClick={() => join.mutate()}
          >
            Entrar na sala
          </button>
          {join.error && (
            <span role="alert" className="form-error">
              {join.error.message}
            </span>
          )}
        </p>
      )}
      <p className="muted" role="status">
        {mode === "live" ? "Ao vivo." : "Sem tempo real agora: a sala atualiza a cada 2 segundos."}
      </p>
    </main>
  );
}

// Um lugar ocupado: o apelido, se criou a sala e se já está pronto.
function Seat(props: { player: RoomPlayer; ownerId: number; onKick?: () => void }) {
  const { player } = props;
  const state = player.ready
    ? "Pronto"
    : player.deck_chosen
      ? "Deck escolhido"
      : "Escolhendo o deck";
  return (
    <li className={player.ready ? "seat ready" : "seat"}>
      <strong>{player.nickname}</strong>
      {player.user_id === props.ownerId && <span className="badge">Criou a sala</span>}
      <span>{state}</span>
      {props.onKick && (
        <button type="button" className="danger" onClick={props.onKick}>
          Tirar da sala
        </button>
      )}
    </li>
  );
}
