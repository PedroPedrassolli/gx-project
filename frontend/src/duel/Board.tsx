import { displayName, imageUrl, type CardSummary, type Language } from "../catalog/cards.ts";
import type { FieldCard, HandCard, Side, View } from "./api.ts";

// A mesa (escopo 4, "Mesa de duelo"): o lado do outro em cima, com as magias por fora e os
// monstros por dentro; o seu embaixo; e as fases do turno no meio. Monstro em defesa fica
// deitado. Carta sem código está virada para baixo e mostra o verso.
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

export function Board(props: Props) {
  const { view } = props;
  const [mine, theirs] = view.you === 0 ? view.sides : [view.sides[1], view.sides[0]];
  return (
    <div className="board">
      <SideArea {...props} side={theirs} opponent />
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
      <SideArea {...props} side={mine} />
    </div>
  );
}

function SideArea(props: Props & { side: Side; opponent?: boolean }) {
  const { side } = props;
  const name = props.names[side.team];
  const spells = (
    <div className="zone-row">
      <ol className="zones" aria-label={`Magias e armadilhas de ${name}`}>
        {side.spells.map((card, index) => (
          <li key={index} className="zone">
            {card && <CardView {...props} card={card} />}
          </li>
        ))}
      </ol>
      <div className="zone field-zone" aria-label={`Campo de ${name}`} role="group">
        {side.field_spell && <CardView {...props} card={side.field_spell} />}
      </div>
    </div>
  );
  const monsters = (
    <ol className="zones" aria-label={`Monstros de ${name}`}>
      {side.monsters.map((card, index) => (
        <li key={index} className="zone">
          {card && <CardView {...props} card={card} />}
        </li>
      ))}
    </ol>
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
    <p className="side-info">
      <strong>{name}</strong> <span className="lp">PV {side.lp}</span> <span>Deck {side.deck}</span>{" "}
      <span>Extra {side.extra}</span> <span>Cemitério {side.grave.length}</span>{" "}
      <span>Banidas {side.banished.length}</span>
    </p>
  );
  return (
    <section className={props.opponent ? "side opponent" : "side"} aria-label={`Lado de ${name}`}>
      {props.opponent ? [info, hand, spells, monsters] : [monsters, spells, hand, info]}
    </section>
  );
}

function CardView(props: Props & { card: FieldCard | HandCard }) {
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
  const stats = "atk" in card && card.atk !== undefined && data?.card_type === "Monster";
  return (
    <button
      type="button"
      className={["card", defense && "defense", faceDown && "face-down"].filter(Boolean).join(" ")}
      aria-label={`${name}${faceDown ? ", virada para baixo" : ""}${defense ? ", em defesa" : ""}`}
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
