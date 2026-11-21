import { useEffect, useRef, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { ApiError, request } from "../api.ts";
import { Link, useParams } from "react-router";
import { SESSION_KEY, useSession } from "../account/session.ts";
import { useMediaQuery } from "../catalog/CardPanel.tsx";
import { NO_CARDS, NO_PACKS, useCatalog } from "../catalog/data.ts";
import { useCardLanguage } from "../catalog/language.ts";
import { PageNotice, SignInFirst } from "../PageNotice.tsx";
import { usePageTitle } from "../pageTitle.ts";
import { useRealtime } from "../realtime/useRealtime.ts";
import { matchKey, respond, surrender, useMatch, type MatchState } from "./api.ts";
import { actionablePlaces } from "./actionable.ts";
import { Board } from "./Board.tsx";
import { commandsByPlace, isCommandPrompt, phaseCommands } from "./commands.ts";
import { DuelDetail } from "./DuelDetail.tsx";
import { CardActionsDialog, CommandsDialog, PlainDialog, PromptDialog } from "./DuelDialogs.tsx";
import { ChainStack, DuelLog } from "./DuelSide.tsx";
import { useAlwaysChain } from "./chainSetting.ts";
import { DuelBar, ResultDialog } from "./DuelStatus.tsx";
import { EmotePicker, useEmoteBubbles } from "./Emotes.tsx";
import { withEmote, type EmotePlayer } from "./emotes.ts";
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
import { promptTitle } from "./PromptPanel.tsx";

// Mesa de duelo (escopo 4): a mesa vista pelo jogador, a vez de quem é e o detalhe da carta
// escolhida. A mesa nova chega pelo tempo real (duel.updated) ou pela consulta de reserva.
//
// Desde o GXP-99 a mesa cabe na tela e nada fica embaixo dela: a carta que dá para usar
// brilha e, tocada, abre as ações dela num modal; as outras perguntas abrem num modal que dá
// para minimizar; ir de fase e encerrar o turno ficam na faixa das fases.
export function DuelPage() {
  const id = useParams().id ?? "";
  usePageTitle("Duelo");
  const session = useSession();
  const user = session.data?.user;
  const client = useQueryClient();
  // A frase (GXP-83) entra na mesa guardada: a de quem mandou volta na resposta, a do outro
  // chega pelo tempo real (ou na próxima consulta).
  const addEmote = (emote: Required<EmotePlayer>) =>
    client.setQueryData(
      matchKey(id),
      (old: MatchState | undefined) => old && withEmote(old, emote),
    );
  const mode = useRealtime(user?.id, (event, data) => {
    if (event === "duel.updated" && String((data as MatchState).id) === id) {
      client.setQueryData(matchKey(id), data);
    }
    if (event === "duel.emote" && String((data as { id: number }).id) === id) {
      addEmote(data as Required<EmotePlayer>);
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
  // A carta tocada que tem ações, a lista de todas as ações e a pergunta minimizada valem só
  // para a pergunta em que foram abertas (pelo número dela): a próxima começa do zero. E o
  // "Mais" do celular e o resultado.
  const [acting, setActing] = useState<{ place: string; code: number; seq: number } | null>(null);
  const [allCommandsSeq, setAllCommandsSeq] = useState<number | null>(null);
  const [minimizedSeq, setMinimizedSeq] = useState<number | null>(null);
  const [more, setMore] = useState(false);
  const [resultClosed, setResultClosed] = useState(false);
  const wide = useMediaQuery("(width >= 72rem)");
  const cards = catalog.data?.byCode ?? NO_CARDS;
  const packs = catalog.data?.packNames ?? NO_PACKS;
  const emotes = useEmoteBubbles(match.data?.players ?? []);
  // "Sempre perguntar" (GXP-84): o navegador guarda; quando a mesa diz outra coisa (duelo
  // novo, ou a escolha mudou), manda a do navegador.
  const [alwaysChain, setAlwaysChain] = useAlwaysChain();
  const { mutate: saveChain, isPending: savingChain } = useMutation({
    mutationFn: (value: boolean) =>
      request("POST", `/api/matches/${id}/settings`, { always_chain: value }),
    onSuccess: (_, value) =>
      client.setQueryData(matchKey(id), (old: MatchState | undefined) =>
        old ? { ...old, always_chain: value } : old,
      ),
  });
  const serverChain = match.data?.always_chain;
  const dueling = match.data?.status === "dueling";
  useEffect(() => {
    if (dueling && serverChain !== undefined && serverChain !== alwaysChain && !savingChain) {
      saveChain(alwaysChain);
    }
  }, [dueling, serverChain, alwaysChain, savingChain, saveChain]);
  const say = useMutation({
    mutationFn: async (emote: string) =>
      (
        await request<{ data: Required<EmotePlayer> }>("POST", `/api/matches/${id}/emotes`, {
          emote,
        })
      ).data,
    onSuccess: addEmote,
  });
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
  const prompt = dueling ? state.view.prompt : undefined;
  const byPlace = commandsByPlace(prompt);
  const actingNow = acting?.seq === state.seq ? acting : null;
  const chain = state.view.chain ?? [];
  const common = {
    you: state.you,
    cards,
    language,
    pending: answer.isPending,
    error: answer.error?.message,
    onAnswer: (response: Record<string, unknown>) => answer.mutate(response),
    onCard: setSelected,
  };
  const side = (
    <>
      <ChainStack chain={chain} you={state.you} names={names} cards={cards} language={language} />
      <DuelLog
        events={state.view.events ?? []}
        you={state.you}
        names={names}
        cards={cards}
        language={language}
      />
      <DuelSettings
        motion={motion}
        onMotion={setMotion}
        alwaysChain={alwaysChain}
        onAlwaysChain={setAlwaysChain}
      />
    </>
  );
  return (
    <main className="page duel-page" ref={page}>
      <h1 className="visually-hidden">Duelo de {names.join(" contra ")}</h1>
      <DuelBar
        state={state}
        names={names}
        surrendering={giveUp.isPending}
        onSurrender={() => giveUp.mutate()}
        onTimeUp={() => match.refetch()}
      >
        <EmotePicker
          pending={say.isPending}
          error={say.error?.message}
          onSend={(emote) => say.mutate(emote)}
        />
        {!wide && (
          <button type="button" className="secondary" onClick={() => setMore(true)}>
            Mais
          </button>
        )}
      </DuelBar>
      <Board
        view={state.view}
        names={names}
        cards={cards}
        language={language}
        onCard={setSelected}
        onCardAt={(place, code) => {
          if (byPlace.has(place)) setActing({ place, code, seq: state.seq });
          else setSelected(code);
        }}
        finished={!dueling}
        lpChanges={motion === "off" ? undefined : lpChanges(fresh)}
        actionable={actionablePlaces(state.view.prompt)}
        emotes={emotes}
        chain={chain}
        center={
          <TurnActions
            state={state}
            names={names}
            pending={answer.isPending}
            error={prompt && isCommandPrompt(prompt) ? answer.error?.message : undefined}
            onAnswer={common.onAnswer}
            onAllCommands={() => setAllCommandsSeq(state.seq)}
            onRespond={() => setMinimizedSeq(null)}
            onResult={() => setResultClosed(false)}
            title={prompt && !isCommandPrompt(prompt) ? promptTitle(prompt, common) : undefined}
          />
        }
      />
      <DuelDetail
        code={selected}
        cards={cards}
        packs={packs}
        language={language}
        onClose={() => setSelected(null)}
      />
      {wide && <div className="duel-side">{side}</div>}
      {!wide && (
        <PlainDialog id="more-title" title="Duelo" open={more} onClose={() => setMore(false)}>
          <div className="duel-more">{side}</div>
        </PlainDialog>
      )}
      {prompt && !isCommandPrompt(prompt) && (
        <PromptDialog
          key={state.seq}
          {...common}
          prompt={prompt}
          chain={chain}
          names={names}
          minimized={minimizedSeq === state.seq}
          onMinimize={() => setMinimizedSeq(state.seq)}
        />
      )}
      {prompt && isCommandPrompt(prompt) && (
        <>
          <CardActionsDialog
            key={`acoes-${state.seq}`}
            {...common}
            code={actingNow?.code ?? null}
            actions={actingNow ? (byPlace.get(actingNow.place) ?? []) : []}
            onClose={() => setActing(null)}
          />
          <CommandsDialog
            key={`todas-${state.seq}`}
            {...common}
            prompt={prompt}
            open={allCommandsSeq === state.seq}
            onClose={() => setAllCommandsSeq(null)}
          />
        </>
      )}
      {!dueling && (
        <ResultDialog
          state={state}
          names={names}
          open={!resultClosed}
          onClose={() => setResultClosed(true)}
        />
      )}
    </main>
  );
}

// O que fazer agora, na faixa das fases: na sua vez de agir, ir de fase, encerrar o turno e
// a lista de todas as ações; com uma pergunta minimizada, "Responder"; no fim, "Ver o
// resultado"; senão, de quem é a vez. A linha tem sempre a mesma altura: a mesa não pula.
function TurnActions(props: {
  state: MatchState;
  names: string[];
  pending: boolean;
  error?: string;
  title?: string;
  onAnswer: (response: Record<string, unknown>) => void;
  onAllCommands: () => void;
  onRespond: () => void;
  onResult: () => void;
}) {
  const { state } = props;
  const prompt = state.status === "dueling" ? state.view.prompt : undefined;
  let content;
  if (state.status === "finished") {
    content = (
      <button type="button" className="cta" onClick={props.onResult}>
        Ver o resultado
      </button>
    );
  } else if (prompt && isCommandPrompt(prompt)) {
    content = (
      <>
        {phaseCommands(prompt).map((item) => (
          <button
            key={item.command}
            type="button"
            className={item.command === "end" ? "secondary" : "cta"}
            disabled={props.pending}
            onClick={() => props.onAnswer({ command: item.command })}
          >
            {item.label}
          </button>
        ))}
        <button type="button" className="secondary" onClick={props.onAllCommands}>
          Todas as ações
        </button>
      </>
    );
  } else if (prompt && props.title) {
    content = (
      <button type="button" className="cta" onClick={props.onRespond}>
        Responder: {props.title}
      </button>
    );
  } else {
    const waiting = state.view.waiting_for ?? state.view.turn_team;
    content = <span className="turn-waiting">Esperando {props.names[waiting]}…</span>;
  }
  return (
    <div className="turn-actions">
      {content}
      {props.error && (
        <p role="alert" className="form-error duel-error">
          {props.error}
        </p>
      )}
    </div>
  );
}

// As configurações da mesa, embaixo do histórico: a velocidade das animações e a pergunta
// da corrente. Rótulos à esquerda, escolhas à direita, alinhados.
function DuelSettings(props: {
  motion: Motion;
  onMotion: (value: Motion) => void;
  alwaysChain: boolean;
  onAlwaysChain: (value: boolean) => void;
}) {
  return (
    <div className="duel-settings">
      <label htmlFor="duel-motion">Animações</label>
      <select
        id="duel-motion"
        value={props.motion}
        onChange={(event) => props.onMotion(event.target.value as Motion)}
      >
        {MOTIONS.map(([value, label]) => (
          <option key={value} value={value}>
            {label}
          </option>
        ))}
      </select>
      <label htmlFor="duel-chain">Perguntar na corrente</label>
      <select
        id="duel-chain"
        value={props.alwaysChain ? "always" : "auto"}
        onChange={(event) => props.onAlwaysChain(event.target.value === "always")}
      >
        <option value="auto">Só quando der</option>
        <option value="always">Sempre</option>
      </select>
    </div>
  );
}
