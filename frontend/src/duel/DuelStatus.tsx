import { useEffect, useRef, useState, type ReactNode } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Link, useNavigate } from "react-router";
import { ApiError } from "../api.ts";
import { displayName } from "../catalog/cards.ts";
import { useCardLanguage } from "../catalog/language.ts";
import { Thumb } from "../catalog/parts.tsx";
import { roomAction, roomKey } from "../rooms/api.ts";
import type { MatchState, RewardLine, Rewards } from "./api.ts";
import { clock } from "./time.ts";

// A barra do duelo, em cima da mesa (GXP-99): de quem é a vez e quanto tempo falta (escopo
// 3.7), os botões (frases, mais e desistir) e, no fim, o resultado num modal, com o caminho
// de volta para a sala ou para os personagens.

type Props = {
  state: MatchState;
  names: string[];
  surrendering: boolean;
  onSurrender: () => void;
  onTimeUp: () => void;
};

// O relógio da tela anda de segundo em segundo.
function useNow() {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);
  return now;
}

const REASONS: Record<string, (loser: string) => string> = {
  surrender: (loser) => `${loser} desistiu.`,
  timeout: (loser) => `${loser} deixou o tempo acabar.`,
  time_limit: () => "Acabou o tempo do duelo: ganha quem tem mais PV.",
};

export function DuelBar(props: Props & { children?: ReactNode }) {
  const { state } = props;
  const finished = state.status === "finished";
  return (
    <div className="duel-bar">
      {/* O mesmo aviso anuncia a vez e, no fim, quem venceu: o leitor de tela só lê o que muda
          dentro de uma região que já estava na página. */}
      <p className="duel-status" role="status">
        {finished ? resultTitle(props) : turnText(props)}
      </p>
      {/* Pergunta nova, prazo novo: o relógio recomeça (e volta a avisar quando zerar). */}
      {!finished && <Timers key={state.deadline_at ?? "sem-prazo"} {...props} />}
      <span className="duel-bar-actions">
        {props.children}
        {!finished && <SurrenderButton {...props} />}
      </span>
    </div>
  );
}

function turnText({ state, names }: Pick<Props, "state" | "names">) {
  const waiting = state.view.waiting_for ?? state.view.turn_team;
  return waiting === state.you ? "Sua vez." : `Vez de ${names[waiting]}…`;
}

function resultTitle({ state, names }: Pick<Props, "state" | "names">) {
  const winner = state.winner_team;
  if (winner === null) return "Empate.";
  return winner === state.you ? "Você venceu!" : `${names[winner]} venceu.`;
}

// O resultado abre sozinho quando o duelo acaba; "Ver a mesa" fecha, e a faixa das fases
// mostra "Ver o resultado" para abrir de novo.
export function ResultDialog(props: {
  state: MatchState;
  names: string[];
  open: boolean;
  onClose: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const element = dialog.current;
    if (props.open && element && !element.open) element.showModal();
    if (!props.open && element?.open) element.close();
  }, [props.open]);
  return (
    <dialog
      ref={dialog}
      className="duel-dialog duel-result"
      closedby="any"
      aria-labelledby="result-title"
      onClose={props.onClose}
    >
      {props.open && (
        <>
          <Result {...props} />
          {props.state.character ? (
            <BackToCharacters state={props.state} />
          ) : (
            <BackToRoom code={props.state.room_code} matchId={props.state.id} />
          )}
          <form method="dialog">
            <button type="submit" className="secondary">
              Ver a mesa
            </button>
          </form>
        </>
      )}
    </dialog>
  );
}

// O prazo da pergunta e o tempo que sobra de duelo. Fora do aviso (role="status") para o
// leitor de tela não ler a cada segundo; ao zerar, a tela consulta a partida.
function Timers(props: Props) {
  const now = useNow();
  const { deadline_at: deadline, ends_at: ends } = props.state;
  const left = deadline ? Date.parse(deadline) - now : null;
  const asked = useRef(false);
  const { onTimeUp } = props;
  useEffect(() => {
    if (left === null || left > 0 || asked.current) return;
    asked.current = true;
    onTimeUp();
  }, [left, onTimeUp]);
  // A sala sem limite nos dois tempos (GXP-80): diz isso, em vez de um relógio vazio.
  if (left === null && !ends) return <p className="duel-timers">Sem limite de tempo</p>;
  return (
    <p className="duel-timers">
      {left !== null && (
        <span role="timer" className={left < 15_000 ? "urgent" : undefined}>
          Resposta: {clock(left)}
        </span>
      )}
      {ends && <span role="timer">Duelo: {clock(Date.parse(ends) - now)}</span>}
    </p>
  );
}

// Desistir pede confirmação num <dialog>. O "Continuar jogando" vem primeiro porque o
// <dialog> foca o primeiro botão ao abrir: um Enter sem querer não encerra o duelo.
function SurrenderButton(props: Props) {
  const dialog = useRef<HTMLDialogElement>(null);
  return (
    <>
      <button type="button" className="secondary" onClick={() => dialog.current?.showModal()}>
        Desistir
      </button>
      <dialog
        ref={dialog}
        className="pile-dialog"
        closedby="any"
        aria-labelledby="surrender-title"
        onClose={() => {
          if (dialog.current?.returnValue === "surrender") props.onSurrender();
          if (dialog.current) dialog.current.returnValue = "";
        }}
      >
        <h2 id="surrender-title">Desistir do duelo?</h2>
        <p>Você perde, e a sala volta a esperar os dois ficarem prontos.</p>
        <form method="dialog" className="dialog-actions">
          <button type="submit" value="" className="secondary">
            Continuar jogando
          </button>
          <button type="submit" value="surrender" className="danger" disabled={props.surrendering}>
            Desistir
          </button>
        </form>
      </dialog>
    </>
  );
}

function Result({ state, names }: Pick<Props, "state" | "names">) {
  const winner = state.winner_team;
  const loser = winner === null ? "" : winner === state.you ? (names[1 - winner] ?? "") : "Você";
  const reason = REASONS[state.finish_reason ?? ""]?.(loser);
  return (
    <>
      <h2 id="result-title">{resultTitle({ state, names })}</h2>
      {reason && <p>{reason}</p>}
      {state.rewards && <RewardsTable rewards={state.rewards} />}
    </>
  );
}

const number = (value: number) => value.toLocaleString("pt-BR");
const signed = (value: number) => `${value < 0 ? "−" : "+"}${number(Math.abs(value))} DP`;

// O DP do duelo (GXP-85): cada bônus, os cortes do anti-farm, a subida de nível e o total.
function RewardsTable({ rewards }: { rewards: Rewards }) {
  const rows = (lines: RewardLine[], className?: string) =>
    lines.map((line, index) => (
      <tr key={`${line.key}-${index}`} className={className}>
        <th scope="row">{line.label}</th>
        <td>{signed(line.dp)}</td>
      </tr>
    ));
  const challenges = rewards.challenges ?? [];
  return (
    <>
      {rewards.card && <NewCard card={rewards.card} />}
      {rewards.unlocked && (
        <p className="new-challenges">Personagem liberado: {rewards.unlocked.name}.</p>
      )}
      {rewards.missions?.map((mission) => (
        <div key={mission.name} className="new-challenges">
          <p>
            <Link to="/desafios">Missão concluída: {mission.name}</Link>
          </p>
          <p>
            {mission.card
              ? `Você ganhou a carta ${mission.card}.`
              : `Pacotes liberados na loja: ${mission.packs.join(" e ")}.`}
          </p>
        </div>
      ))}
      {challenges.length > 0 && (
        <div className="new-challenges">
          <p>
            <Link to="/desafios">
              {challenges.length === 1 ? "Desafio concluído" : "Desafios concluídos"}
            </Link>
          </p>
          <ul>
            {challenges.map((challenge) => (
              <li key={challenge.number}>{challenge.label}</li>
            ))}
          </ul>
        </div>
      )}
      <table className="rewards">
        <caption>DP do duelo</caption>
        <tbody>
          {rows(rewards.lines)}
          {rows(rewards.cuts, "cut")}
          {rows(rewards.level_ups, "level-up")}
        </tbody>
        <tfoot>
          <tr>
            <th scope="row">Total</th>
            <td>{signed(rewards.total)}</td>
          </tr>
        </tfoot>
      </table>
      <p className="balance">
        Saldo: {number(rewards.balance)} DP. Nível {rewards.level}.
      </p>
    </>
  );
}

// A carta-símbolo da primeira vitória contra o personagem, já na coleção.
function NewCard({ card }: { card: NonNullable<Rewards["card"]> }) {
  const [language] = useCardLanguage();
  return (
    <div className="new-challenges new-card">
      <Thumb card={card} />
      <p>
        Você ganhou a carta {displayName(card, language)}! Ela já está na{" "}
        <Link to="/colecao">sua coleção</Link>.
      </p>
    </div>
  );
}

// Contra personagem: enfrentar quem a vitória liberou, duelar de novo (o modal do deck abre
// direto), a lista e o replay.
function BackToCharacters({ state }: { state: MatchState }) {
  const unlocked = state.rewards?.unlocked;
  return (
    <p className="duel-actions">
      {unlocked && (
        <Link className="cta" to={`/personagens?duelar=${unlocked.id}`}>
          Duelar contra {unlocked.name}
        </Link>
      )}
      <Link
        className={unlocked ? "cta secondary" : "cta"}
        to={`/personagens?duelar=${state.character}`}
      >
        Duelar de novo
      </Link>
      <Link className="cta secondary" to="/personagens">
        Ver os personagens
      </Link>
      <Link className="cta secondary" to={`/duelo/${state.id}/replay`}>
        Ver o replay
      </Link>
    </p>
  );
}

// No fim: a revanche com um clique (fica pronto com o mesmo deck e volta para a sala), a
// sala e o replay, que fica 30 dias. Se a sala sumiu, a lista de salas.
function BackToRoom({ code, matchId }: { code?: string | null; matchId: number }) {
  const navigate = useNavigate();
  const client = useQueryClient();
  const rematch = useMutation({
    mutationFn: () => roomAction(code ?? "", "ready", { ready: true }),
    onSuccess: (room) => {
      if (room) client.setQueryData(roomKey(room.code), room);
      navigate(`/salas/${code}`);
    },
  });
  const closed = rematch.error instanceof ApiError && rematch.error.status === 404;
  return (
    <>
      <p className="duel-actions">
        {code && (
          <button
            type="button"
            className="cta"
            disabled={rematch.isPending}
            onClick={() => rematch.mutate()}
          >
            Revanche
          </button>
        )}
        <Link className={code ? "cta secondary" : "cta"} to={code ? `/salas/${code}` : "/salas"}>
          {code ? "Voltar para a sala" : "Ver as salas"}
        </Link>
        <Link className="cta secondary" to={`/duelo/${matchId}/replay`}>
          Ver o replay
        </Link>
      </p>
      {rematch.error && (
        <p role="alert" className="form-error duel-actions-error">
          {closed ? "A sala fechou: quem criou saiu." : rematch.error.message}
        </p>
      )}
    </>
  );
}
