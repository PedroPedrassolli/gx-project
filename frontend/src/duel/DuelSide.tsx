import { displayName, type CardSummary, type Language } from "../catalog/cards.ts";
import type { ChainLink, DuelEvent } from "./api.ts";
import { describe } from "./log.ts";

// Ao lado da mesa: a corrente aberta e o histórico do duelo (escopo 4: "Pilha da cadeia.
// Log." e "o log é lido por leitor de tela").

type Props = {
  you: number;
  names: string[];
  cards: Map<number, CardSummary>;
  language: Language;
};

// O elo mais alto em cima, como numa pilha: é ele que resolve primeiro.
export function ChainStack(props: Props & { chain: ChainLink[] }) {
  if (props.chain.length === 0) return null;
  const owner = (team: number) =>
    team === props.you ? "sua" : `de ${props.names[team] ?? "Duelista"}`;
  return (
    <section className="chain-stack" aria-labelledby="chain-title">
      <h2 id="chain-title">Corrente</h2>
      <ol reversed>
        {[...props.chain].reverse().map((link) => {
          const card = props.cards.get(link.code);
          return (
            <li key={link.link} value={link.link} className={link.negated ? "negated" : undefined}>
              <strong>{card ? displayName(card, props.language) : `Carta ${link.code}`}</strong>,{" "}
              {owner(link.controller)}
              {link.negated && <span className="tag">negado</span>}
              {link.text && <span className="choice-detail">{link.text}</span>}
            </li>
          );
        })}
      </ol>
    </section>
  );
}

// Uma linha por evento, a mais nova em cima. A lista avisa o leitor de tela das linhas
// novas (aria-live).
export function DuelLog(props: Props & { events: DuelEvent[] }) {
  // O nome da carta pode terminar em ponto ("Guerreiro D.D."): um ponto só no fim da linha.
  const lines = props.events.flatMap((event) => {
    const text = describe(event, props);
    return text ? [{ id: event.id, text: text.replace(/\.\.$/, ".") }] : [];
  });
  return (
    <section className="duel-log" aria-labelledby="log-title">
      <h2 id="log-title">Histórico</h2>
      {lines.length === 0 ? (
        <p className="pick-count">Nada aconteceu ainda.</p>
      ) : (
        <ol tabIndex={0} aria-labelledby="log-title" aria-live="polite" aria-relevant="additions">
          {lines.reverse().map((line) => (
            <li key={line.id}>{line.text}</li>
          ))}
        </ol>
      )}
    </section>
  );
}
