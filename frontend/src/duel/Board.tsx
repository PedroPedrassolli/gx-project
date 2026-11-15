import { useEffect, useRef, useState } from "react";
import { displayName, imageUrl, type CardSummary, type Language } from "../catalog/cards.ts";
import type { FieldCard, HandCard, Side, View } from "./api.ts";

// A mesa (escopo 4, "Mesa de duelo"), como numa mesa de verdade: o seu campo embaixo, com a
// zona de campo e o Extra à esquerda e o cemitério e o deck à direita; o do outro em cima,
// girado (o lado esquerdo dele fica à sua direita). As fases do turno no meio. Monstro em
// defesa fica deitado; carta sem código está virada para baixo e mostra o verso.
const PHASES = [
  ["draw", "Compra"],
  ["standby", "Apoio"],
  ["main1", "Principal 1"],
  ["battle", "Batalha"],
  ["main2", "Principal 2"],
  ["end", "Final"],
] as const;

type Props = {
  view: View;
  names: string[];
  cards: Map<number, CardSummary>;
  language: Language;
  onCard: (code: number) => void;
};

// Uma pilha aberta: o título e as cartas, de cima (a última que entrou) para baixo.
type Pile = { title: string; cards: HandCard[] };

export function Board(props: Props) {
  const { view } = props;
  const [mine, theirs] = view.you === 0 ? view.sides : [view.sides[1], view.sides[0]];
  const [pile, setPile] = useState<Pile | null>(null);
  return (
    <div className="board">
      <SideArea {...props} side={theirs} opponent onPile={setPile} />
      <div className="phase-track">
        <p>
          Turno {view.turn}, vez de {props.names[view.turn_team]}
        </p>
        <ol aria-label="Fases do turno">
          {PHASES.map(([key, label]) => (
            <li key={key} aria-current={view.phase === key ? "step" : undefined}>
              {label}
            </li>
          ))}
        </ol>
      </div>
      <SideArea {...props} side={mine} onPile={setPile} />
      <PileDialog {...props} pile={pile} onClose={() => setPile(null)} />
    </div>
  );
}

function SideArea(props: Props & { side: Side; opponent?: boolean; onPile: (pile: Pile) => void }) {
  const { side } = props;
  const name = props.names[side.team] ?? "Duelista";
  const team = side.team;
  const label = (pile: string, own: string) => (props.opponent ? `${pile} de ${name}` : own);
  const open = (title: string, cards: HandCard[]) => () =>
    props.onPile({ title, cards: [...cards].reverse() });
  const field = (
    <div className="field-grid">
      <div className="zone field-zone pile-field" role="group" aria-label={`Campo de ${name}`}>
        {side.field_spell && <CardView {...props} card={side.field_spell} place={`${team}-8-5`} />}
      </div>
      <ol className="zones monster-row" aria-label={`Monstros de ${name}`}>
        {side.monsters.map((card, index) => (
          <li key={index} className="zone" data-place={`${team}-4-${index}`}>
            {card && <CardView {...props} card={card} />}
          </li>
        ))}
      </ol>
      <ol className="zones spell-row" aria-label={`Magias e armadilhas de ${name}`}>
        {side.spells.map((card, index) => (
          <li key={index} className="zone" data-place={`${team}-8-${index}`}>
            {card && <CardView {...props} card={card} />}
          </li>
        ))}
      </ol>
      <PileButton
        {...props}
        className="pile-grave"
        label={label("Cemitério", "Seu cemitério")}
        pile={side.grave}
        onOpen={open(label("Cemitério", "Seu cemitério"), side.grave)}
      />
      <div
        className="zone pile pile-deck"
        role="group"
        aria-label={`${label("Deck", "Seu deck")}, ${count(side.deck)}`}
      >
        {side.deck > 0 && <span className="card back" aria-hidden="true" />}
        <span className="pile-count" aria-hidden="true">
          {side.deck}
        </span>
      </div>
      {side.extra_cards ? (
        <PileButton
          {...props}
          className="pile-extra"
          label="Seu Extra"
          pile={side.extra_cards}
          hideTop
          onOpen={open("Seu Extra", side.extra_cards)}
        />
      ) : (
        <div
          className="zone pile pile-extra"
          role="group"
          aria-label={`${label("Extra", "Seu Extra")}, ${count(side.extra)}`}
        >
          {side.extra > 0 && <span className="card back" aria-hidden="true" />}
          <span className="pile-count" aria-hidden="true">
            {side.extra}
          </span>
        </div>
      )}
    </div>
  );
  const hand = (
    <ol className="hand" aria-label={props.opponent ? `Mão de ${name}` : "Sua mão"}>
      {side.hand.map((card, index) => (
        <li key={index}>
          <CardView {...props} card={card} />
        </li>
      ))}
    </ol>
  );
  const info = (
    <div className="side-info">
      <strong>{name}</strong>
      <span className="lp" data-lp={team}>
        PV {side.lp}
      </span>
      <button
        type="button"
        className="pile-banished"
        onClick={open(label("Cartas banidas", "Suas cartas banidas"), side.banished)}
      >
        Banidas {side.banished.length}
      </button>
    </div>
  );
  return (
    <section className={props.opponent ? "side opponent" : "side"} aria-label={`Lado de ${name}`}>
      {props.opponent ? (
        <>
          {info}
          {hand}
          {field}
        </>
      ) : (
        <>
          {field}
          {hand}
          {info}
        </>
      )}
    </section>
  );
}

const count = (total: number) => (total === 1 ? "1 carta" : `${total} cartas`);

// Cemitério ou Extra: a carta de cima à vista (no cemitério) e a quantidade; o toque abre
// a lista.
function PileButton(
  props: Props & {
    className: string;
    label: string;
    pile: HandCard[];
    hideTop?: boolean;
    onOpen: () => void;
  },
) {
  const top = props.hideTop ? undefined : props.pile.at(-1)?.code;
  return (
    <button
      type="button"
      className={`zone pile ${props.className}`}
      aria-label={`${props.label}, ${count(props.pile.length)}`}
      onClick={props.onOpen}
    >
      {top ? (
        <TopCard {...props} code={top} />
      ) : (
        props.pile.length > 0 && <span className="card back" aria-hidden="true" />
      )}
      <span className="pile-count" aria-hidden="true">
        {props.pile.length}
      </span>
    </button>
  );
}

function TopCard(props: Props & { code: number }) {
  const data = props.cards.get(props.code);
  if (data?.image === undefined) return <span className="card" aria-hidden="true" />;
  return (
    <span className="card" aria-hidden="true">
      <img src={imageUrl(data.image, "p")} alt="" width={56} height={82} decoding="async" />
    </span>
  );
}

// A lista de uma pilha num diálogo (o <dialog> nativo cuida do foco, do Esc e do fundo).
function PileDialog(props: Props & { pile: Pile | null; onClose: () => void }) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    if (props.pile && !dialog.current?.open) dialog.current?.showModal();
  }, [props.pile]);
  return (
    <dialog
      ref={dialog}
      className="pile-dialog"
      closedby="any"
      aria-labelledby="pile-title"
      onClose={props.onClose}
    >
      {props.pile && (
        <>
          <h2 id="pile-title">
            {props.pile.title} ({props.pile.cards.length})
          </h2>
          {props.pile.cards.length === 0 ? (
            <p>Nenhuma carta.</p>
          ) : (
            <ul className="pile-list">
              {props.pile.cards.map((card, index) => (
                <li key={index}>
                  <PileCard
                    {...props}
                    card={card}
                    onShow={(code) => {
                      dialog.current?.close();
                      props.onCard(code);
                    }}
                  />
                </li>
              ))}
            </ul>
          )}
          <form method="dialog">
            <button type="submit" autoFocus>
              Fechar
            </button>
          </form>
        </>
      )}
    </dialog>
  );
}

function PileCard(props: Props & { card: HandCard; onShow: (code: number) => void }) {
  const code = props.card.code;
  if (!code) return <span className="pile-card">Carta virada para baixo</span>;
  const data = props.cards.get(code);
  return (
    <button type="button" className="pile-card" onClick={() => props.onShow(code)}>
      {data?.image !== undefined && (
        <img src={imageUrl(data.image, "p")} alt="" width={28} height={41} decoding="async" />
      )}
      {data ? displayName(data, props.language) : `Carta ${code}`}
    </button>
  );
}

function CardView(props: Props & { card: FieldCard | HandCard; place?: string }) {
  const { card } = props;
  const defense = "defense" in card && card.defense;
  if (!card.code) {
    return (
      <span
        className={defense ? "card back defense" : "card back"}
        role="img"
        aria-label="Carta virada para baixo"
      />
    );
  }

  const code = card.code;
  const data = props.cards.get(code);
  const name = data ? displayName(data, props.language) : `Carta ${code}`;
  const faceDown = "face_down" in card && card.face_down;
  const revealed = "public" in card && card.public;
  const stats = "atk" in card && card.atk !== undefined && data?.card_type === "Monster";
  return (
    <button
      type="button"
      className={["card", defense && "defense", faceDown && "face-down", revealed && "revealed"]
        .filter(Boolean)
        .join(" ")}
      aria-label={`${name}${faceDown ? ", virada para baixo" : ""}${defense ? ", em defesa" : ""}${revealed ? ", revelada" : ""}`}
      onClick={() => props.onCard(code)}
    >
      {data?.image !== undefined ? (
        <img src={imageUrl(data.image, "p")} alt="" width={56} height={82} decoding="async" />
      ) : (
        <span className="card-name">{name}</span>
      )}
      {stats && (
        <span className="card-stats">
          {card.atk}/{card.def}
        </span>
      )}
    </button>
  );
}
