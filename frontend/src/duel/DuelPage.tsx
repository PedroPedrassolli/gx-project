import { useMemo, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { ApiError } from "../api.ts";
import { Link, useParams } from "react-router";
import { useSession } from "../account/session.ts";
import type { CardSummary } from "../catalog/cards.ts";
import { useCardDetail, useCatalog } from "../catalog/data.ts";
import { useCardLanguage } from "../catalog/language.ts";
import { Detail } from "../catalog/parts.tsx";
import { usePageTitle } from "../pageTitle.ts";
import { useRealtime } from "../realtime/useRealtime.ts";
import { matchKey, respond, useMatch, type MatchState } from "./api.ts";
import { Board } from "./Board.tsx";
import { ChainStack, DuelLog } from "./DuelSide.tsx";
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
  const catalog = useCatalog();
  const [language] = useCardLanguage();
  const [selected, setSelected] = useState<number | null>(null);
  const cards = useMemo(() => {
    const byCode = new Map<number, CardSummary>();
    for (const card of catalog.data?.cards ?? [])
      if (card.code !== undefined) byCode.set(card.code, card);
    return byCode;
  }, [catalog.data]);
  const selectedCard = selected === null ? undefined : cards.get(selected);
  const detail = useCardDetail(selectedCard?.id ?? 0);
  const packs = useMemo(
    () => new Map(catalog.data?.packs.map((pack) => [pack.id, pack.name])),
    [catalog.data],
  );
  // A mesa nova volta na própria resposta. Se a mesa mudou antes (409), busca de novo.
  const answer = useMutation({
    mutationFn: (response: Record<string, unknown>) => respond(id, match.data?.seq ?? 0, response),
    onSuccess: (data) => client.setQueryData(matchKey(id), data),
    onError: (error) => {
      if (error instanceof ApiError && error.status === 409) match.refetch();
    },
  });

  if (session.isSuccess && !user) {
    return (
      <main className="page narrow">
        <h1>Duelo</h1>
        <p>
          <Link to="/entrar">Entre na sua conta</Link> para jogar.
        </p>
      </main>
    );
  }
  if (match.error) {
    return (
      <main className="page narrow">
        <h1>Duelo</h1>
        <p role="alert">Não achamos este duelo.</p>
        <p>
          <Link to="/salas">Ver as salas</Link>
        </p>
      </main>
    );
  }
  if (!match.data) {
    return (
      <main className="page narrow">
        <h1>Duelo</h1>
        <p role="status">Carregando a mesa…</p>
      </main>
    );
  }

  const state = match.data;
  const names = [0, 1].map(
    (team) => state.players.find((player) => player.team === team)?.nickname ?? "Duelista",
  );
  return (
    <main className="page duel-page">
      <h1 className="visually-hidden">Duelo de {names.join(" contra ")}</h1>
      <Board
        view={state.view}
        names={names}
        cards={cards}
        language={language}
        onCard={setSelected}
      />
      <p className="duel-status" role="status">
        {status(state, names)}
      </p>
      {selectedCard && detail.data ? (
        <section className="card-detail duel-detail" aria-labelledby="detail-title">
          <Detail card={detail.data} language={language} packs={packs} />
          <button type="button" className="duel-detail-close" onClick={() => setSelected(null)}>
            Fechar o detalhe
          </button>
        </section>
      ) : (
        <section className="duel-detail duel-detail-empty" aria-labelledby="detail-empty-title">
          <h2 id="detail-empty-title">Carta</h2>
          <p>Toque numa carta para ver o detalhe dela.</p>
        </section>
      )}
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
      </div>
    </main>
  );
}

function status(state: MatchState, names: string[]) {
  if (state.status === "finished") {
    if (state.winner_team === null) return "Empate.";
    return state.winner_team === state.you ? "Você venceu!" : `${names[state.winner_team]} venceu.`;
  }
  if (state.view.waiting_for === state.you) return "Sua vez.";
  return `Vez de ${names[state.view.waiting_for ?? state.view.turn_team]}…`;
}
