import { useEffect, useRef, useState } from "react";
import { Link } from "react-router";
import type { MatchState } from "./api.ts";
import { clock } from "./time.ts";

// A situação do duelo embaixo da mesa: de quem é a vez e quanto tempo falta (escopo 3.7),
// o botão de desistir e, no fim, o resultado com o caminho de volta para a sala.

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
  time_limit: () => "Acabaram os 60 minutos: ganha quem tem mais PV.",
};

export function DuelStatus(props: Props) {
  const { state } = props;
  const finished = state.status === "finished";
  return (
    <div className={finished ? "duel-status-area duel-result" : "duel-status-area"}>
      {/* O mesmo aviso anuncia a vez e, no fim, o resultado: o leitor de tela só lê o que
          muda dentro de uma região que já estava na página. */}
      <div className="duel-status" role="status">
        {finished ? <Result {...props} /> : <Turn {...props} />}
      </div>
      {finished ? (
        <BackToRoom code={state.room_code} />
      ) : (
        <>
          {/* Pergunta nova, prazo novo: o relógio recomeça (e volta a avisar quando zerar). */}
          <Timers key={state.deadline_at ?? "sem-prazo"} {...props} />
          <SurrenderButton {...props} />
        </>
      )}
    </div>
  );
}

function Turn({ state, names }: Props) {
  const waiting = state.view.waiting_for ?? state.view.turn_team;
  return <p>{waiting === state.you ? "Sua vez." : `Vez de ${names[waiting]}…`}</p>;
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
      <p className="duel-actions">
        <button type="button" className="secondary" onClick={() => dialog.current?.showModal()}>
          Desistir
        </button>
      </p>
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

function Result({ state, names }: Props) {
  const winner = state.winner_team;
  const title =
    winner === null
      ? "Empate."
      : winner === state.you
        ? "Você venceu!"
        : `${names[winner]} venceu.`;
  const loser = winner === null ? "" : winner === state.you ? (names[1 - winner] ?? "") : "Você";
  const reason = REASONS[state.finish_reason ?? ""]?.(loser);
  return (
    <>
      <h2>{title}</h2>
      {reason && <p>{reason}</p>}
    </>
  );
}

// No fim, o caminho de volta: a sala reabre para a revanche (ou a lista, se a sala sumiu).
function BackToRoom({ code }: { code?: string | null }) {
  return (
    <p className="duel-actions">
      <Link className="cta" to={code ? `/salas/${code}` : "/salas"}>
        {code ? "Voltar para a sala" : "Ver as salas"}
      </Link>
    </p>
  );
}
