import { useEffect, useMemo, useState } from "react";
import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { Link, useParams } from "react-router";
import { request } from "../api.ts";
import { useSession } from "../account/session.ts";
import { useMediaQuery } from "../catalog/CardPanel.tsx";
import { NO_CARDS, NO_PACKS, useCatalog } from "../catalog/data.ts";
import { useCardLanguage } from "../catalog/language.ts";
import { PageNotice, SignInFirst } from "../PageNotice.tsx";
import { usePageTitle } from "../pageTitle.ts";
import type { View } from "./api.ts";
import { Board, PhaseTrack } from "./Board.tsx";
import { DuelDetail } from "./DuelDetail.tsx";
import { withEngineCards } from "./engineCards.ts";
import { ChainStack, DuelLog } from "./DuelSide.tsx";

// Replay do duelo (escopo 3.7): um turno por vez, a mesa de quem assiste depois de cada lance
// e o histórico do turno até ali. "Reproduzir" passa sozinho; "Pausar" para.
type ReplayTurn = {
  id: number;
  turn: number;
  turns: number;
  you: number;
  players: { team: number; nickname: string }[];
  frames: { step: number; view: View }[];
};

const STEP_MS = 1500;

export function ReplayPage() {
  const id = useParams().id ?? "";
  usePageTitle("Replay");
  const session = useSession();
  const user = session.data?.user;
  // No computador, a faixa das fases vai para a coluna da direita, como no duelo (GXP-135).
  const wide = useMediaQuery("(width >= 72rem)");
  const [turn, setTurn] = useState(1);
  // Lance do turno; -1 é o último (voltar do começo de um turno para o fim do anterior).
  const [frame, setFrame] = useState(0);
  const [playing, setPlaying] = useState(false);
  const replay = useQuery({
    queryKey: ["replay", id, turn],
    queryFn: async () =>
      (await request<{ data: ReplayTurn }>("GET", `/api/matches/${id}/replay?turn=${turn}`)).data,
    staleTime: Infinity,
    placeholderData: keepPreviousData,
    retry: false,
    enabled: Boolean(user),
  });
  const catalog = useCatalog();
  const [language] = useCardLanguage();
  const [selected, setSelected] = useState<number | null>(null);
  const packs = catalog.data?.packNames ?? NO_PACKS;

  const data = replay.data;
  const frames = data?.frames ?? [];
  // As fichas e as cartas de fora do catálogo de todos os quadros do turno: o histórico mostra
  // o turno até o quadro atual (GXP-141).
  const cards = useMemo(
    () =>
      withEngineCards(
        catalog.data?.byCode ?? NO_CARDS,
        (data?.frames ?? []).map((item) => item.view.cards),
      ),
    [catalog.data, data],
  );
  const index = frame < 0 ? frames.length - 1 : Math.min(frame, frames.length - 1);
  const turns = data?.turns ?? 1;
  const atStart = turn === 1 && index <= 0;
  const atEnd = turn >= turns && index >= frames.length - 1;

  function next() {
    if (index < frames.length - 1) return setFrame(index + 1);
    if (turn < turns) {
      setTurn(turn + 1);
      return setFrame(0);
    }
    setPlaying(false);
  }

  function previous() {
    if (index > 0) return setFrame(index - 1);
    if (turn > 1) {
      setTurn(turn - 1);
      setFrame(-1);
    }
  }

  // Reproduzindo: um lance a cada STEP_MS, esperando o turno seguinte chegar.
  useEffect(() => {
    if (!playing || replay.isPlaceholderData) return;
    const timer = setTimeout(next, STEP_MS);
    return () => clearTimeout(timer);
  });

  if (session.isSuccess && !user) {
    return <SignInFirst title="Replay" reason="para ver o replay" />;
  }
  if (replay.error) {
    return (
      <PageNotice title="Replay">
        <p role="alert">{replay.error.message}</p>
        <p>
          <Link to={`/duelo/${id}`}>Voltar para o duelo</Link>
        </p>
      </PageNotice>
    );
  }
  const current = frames[index];
  if (!data || !current) {
    return (
      <PageNotice title="Replay">
        <p role="status">Carregando o replay…</p>
      </PageNotice>
    );
  }

  const names = [0, 1].map(
    (team) => data.players.find((player) => player.team === team)?.nickname ?? "Duelista",
  );
  const boardProps = { view: current.view, names, cards, language, onCard: setSelected };
  return (
    <main className="page duel-page replay-page">
      <h1 className="visually-hidden">Replay do duelo de {names.join(" contra ")}</h1>
      <Board {...boardProps} track={!wide} />
      <div className="duel-status-area replay-controls">
        <p className="duel-status">
          Turno {turn} de {turns}
        </p>
        <p>
          Lance {index + 1} de {frames.length}
        </p>
        <p className="replay-buttons">
          <button type="button" className="secondary" disabled={atStart} onClick={previous}>
            Anterior
          </button>
          <button type="button" disabled={atEnd} onClick={() => setPlaying(!playing)}>
            {playing ? "Pausar" : "Reproduzir"}
          </button>
          <button type="button" className="secondary" disabled={atEnd} onClick={next}>
            Próximo
          </button>
        </p>
        <p className="replay-jump">
          <label htmlFor="replay-turn">Ir para o turno</label>
          <select
            id="replay-turn"
            value={turn}
            onChange={(event) => {
              setTurn(Number(event.target.value));
              setFrame(0);
            }}
          >
            {Array.from({ length: turns }, (_, item) => (
              <option key={item + 1} value={item + 1}>
                {item + 1}
              </option>
            ))}
          </select>
        </p>
        <p>
          <Link to={`/duelo/${id}`}>Voltar para o resultado</Link>
        </p>
      </div>
      <DuelDetail
        code={selected}
        cards={cards}
        packs={packs}
        language={language}
        onClose={() => setSelected(null)}
      />
      <div className="duel-side">
        {wide && <PhaseTrack {...boardProps} />}
        <ChainStack
          chain={current.view.chain ?? []}
          you={data.you}
          names={names}
          cards={cards}
          language={language}
        />
        <DuelLog
          events={frames.slice(0, index + 1).flatMap((item) => item.view.events ?? [])}
          you={data.you}
          names={names}
          cards={cards}
          language={language}
        />
      </div>
    </main>
  );
}
