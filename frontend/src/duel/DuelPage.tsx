import { useEffect, useRef, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { ApiError } from "../api.ts";
import { Link, useParams } from "react-router";
import { SESSION_KEY, useSession } from "../account/session.ts";
import { NO_CARDS, NO_PACKS, useCatalog } from "../catalog/data.ts";
import { useCardLanguage } from "../catalog/language.ts";
import { PageNotice, SignInFirst } from "../PageNotice.tsx";
import { usePageTitle } from "../pageTitle.ts";
import { useRealtime } from "../realtime/useRealtime.ts";
import { matchKey, respond, surrender, useMatch, type MatchState } from "./api.ts";
import { actionablePlaces } from "./actionable.ts";
import { Board } from "./Board.tsx";
import { DuelDetail } from "./DuelDetail.tsx";
import { ChainStack, DuelLog } from "./DuelSide.tsx";
import { DuelStatus } from "./DuelStatus.tsx";
import {
  DURATION,
  lastId,
  lpChanges,
  MOTIONS,
  play,
  useFreshEvents,
  useMotion,
  type Motion,
} from "./motion.ts";
import { PromptPanel } from "./PromptPanel.tsx";

// Mesa de duelo (escopo 4): a mesa vista pelo jogador, a vez de quem é e o detalhe da carta
// escolhida. A mesa nova chega pelo tempo real (duel.updated) ou pela consulta de reserva.
export function DuelPage() {
  const id = useParams().id ?? "";
  usePageTitle("Duelo");
  const session = useSession();
  const user = session.data?.user;
  const client = useQueryClient();
  const mode = useRealtime(user?.id, (event, data) => {
    if (event === "duel.updated" && String((data as MatchState).id) === id) {
      client.setQueryData(matchKey(id), data);
    }
  });
  const match = useMatch(id, mode, Boolean(user));
  // A sessão diz se há duelo em andamento (o aviso de volta à mesa): ela muda quando o duelo
  // começa e quando acaba.
  const status = match.data?.status;
  useEffect(() => {
    if (status) void client.invalidateQueries({ queryKey: SESSION_KEY });
  }, [client, status]);
  const [motion, setMotion] = useMotion();
  const fresh = useFreshEvents(match.data?.view.events);
  const page = useRef<HTMLElement>(null);
  // As animações de entrada (CSS, pelo data-motion) só valem a partir do quadro seguinte ao
  // da primeira mesa: ao abrir a página, as cartas aparecem paradas.
  const hasData = Boolean(match.data);
  useEffect(() => {
    const main = page.current;
    if (!main) return;
    const frame = requestAnimationFrame(() => (main.dataset.motion = motion));
    return () => cancelAnimationFrame(frame);
  }, [motion, hasData]);
  const played = useRef(0);
  const you = match.data?.you ?? 0;
  useEffect(() => {
    const latest = lastId(fresh);
    if (!page.current || latest <= played.current) return;
    const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
    const news = fresh.filter((event) => event.id > played.current);
    if (motion !== "off" && !still) play(page.current, news, you, DURATION[motion]);
    played.current = latest;
  }, [fresh, motion, you]);
  const catalog = useCatalog();
  const [language] = useCardLanguage();
  const [selected, setSelected] = useState<number | null>(null);
  const cards = catalog.data?.byCode ?? NO_CARDS;
  const packs = catalog.data?.packNames ?? NO_PACKS;
  const giveUp = useMutation({
    mutationFn: () => surrender(id),
    onSuccess: (data) => client.setQueryData(matchKey(id), data),
  });
  // A mesa nova volta na própria resposta. Se a mesa mudou antes (409), busca de novo.
  const answer = useMutation({
    mutationFn: (response: Record<string, unknown>) => respond(id, match.data?.seq ?? 0, response),
    onSuccess: (data) => client.setQueryData(matchKey(id), data),
    onError: (error) => {
      if (error instanceof ApiError && error.status === 409) match.refetch();
    },
  });

  if (session.isSuccess && !user) {
    return <SignInFirst title="Duelo" reason="para jogar" />;
  }
  if (match.error) {
    return (
      <PageNotice title="Duelo">
        <p role="alert">Não achamos este duelo.</p>
        <p>
          <Link to="/salas">Ver as salas</Link>
        </p>
      </PageNotice>
    );
  }
  if (!match.data) {
    return (
      <PageNotice title="Duelo">
        <p role="status">Carregando a mesa…</p>
      </PageNotice>
    );
  }

  const state = match.data;
  const names = [0, 1].map(
    (team) => state.players.find((player) => player.team === team)?.nickname ?? "Duelista",
  );
  return (
    <main className="page duel-page" ref={page}>
      <h1 className="visually-hidden">Duelo de {names.join(" contra ")}</h1>
      <Board
        view={state.view}
        names={names}
        cards={cards}
        language={language}
        onCard={setSelected}
        finished={state.status === "finished"}
        lpChanges={motion === "off" ? undefined : lpChanges(fresh)}
        actionable={actionablePlaces(state.view.prompt)}
      />
      <DuelStatus
        state={state}
        names={names}
        surrendering={giveUp.isPending}
        onSurrender={() => giveUp.mutate()}
        onTimeUp={() => match.refetch()}
      />
      <DuelDetail
        code={selected}
        cards={cards}
        packs={packs}
        language={language}
        onClose={() => setSelected(null)}
      />
      {state.status === "dueling" && state.view.prompt && (
        <PromptPanel
          key={state.seq}
          prompt={state.view.prompt}
          you={state.you}
          cards={cards}
          language={language}
          pending={answer.isPending}
          onAnswer={(response) => answer.mutate(response)}
        />
      )}
      {answer.error && (
        <p role="alert" className="form-error duel-error">
          {answer.error.message}
        </p>
      )}
      <div className="duel-side">
        <ChainStack
          chain={state.view.chain ?? []}
          you={state.you}
          names={names}
          cards={cards}
          language={language}
        />
        <DuelLog
          events={state.view.events ?? []}
          you={state.you}
          names={names}
          cards={cards}
          language={language}
        />
        <MotionSetting motion={motion} onChange={setMotion} />
      </div>
    </main>
  );
}

// A velocidade das animações, embaixo do histórico.
function MotionSetting(props: { motion: Motion; onChange: (value: Motion) => void }) {
  return (
    <p className="motion-setting">
      <label htmlFor="duel-motion">Animações</label>
      <select
        id="duel-motion"
        value={props.motion}
        onChange={(event) => props.onChange(event.target.value as Motion)}
      >
        {MOTIONS.map(([value, label]) => (
          <option key={value} value={value}>
            {label}
          </option>
        ))}
      </select>
    </p>
  );
}
