import { useEffect, useRef, useState, type ReactNode } from "react";
import { displayName, imageUrl, type CardSummary, type Language } from "../catalog/cards.ts";
import type { ChainLink, DuelEvent, FieldCard, HandCard, Side, View } from "./api.ts";

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
  // No fim, a mesa fica como acabou, sem "vez de" nem fase marcada.
  finished?: boolean;
  // A última mudança de PV de cada time (animação), sem nada quando as animações estão
  // desligadas.
  lpChanges?: Map<number, DuelEvent>;
  // Onde estão as cartas que a pergunta da vez deixa usar (actionablePlaces): brilham.
  actionable?: Set<string>;
  // A frase que cada time mandou e ainda aparece (emotes).
  emotes?: Map<number, string>;
  // Tocar numa carta com a chave dela ("time-local-posição"): no duelo, a carta que brilha
  // abre as ações e as outras, o detalhe (GXP-99). Sem isso, toda carta abre o detalhe.
  onCardAt?: (place: string, code: number) => void;
  // O que vai na faixa das fases, embaixo da lista das fases (os botões da vez).
  center?: ReactNode;
  // A corrente aberta, que aparece por cima do meio da mesa.
  chain?: ChainLink[];
};

// Uma pilha aberta: o título e as cartas, de cima (a última que entrou) para baixo, cada uma
// com a chave dela (a posição na pilha é a da engine).
type Pile = { title: string; cards: { card: HandCard; place: string }[] };

export function Board(props: Props) {
  const { view } = props;
  const [mine, theirs] = view.you === 0 ? view.sides : [view.sides[1], view.sides[0]];
  const [pile, setPile] = useState<Pile | null>(null);
  return (
    <div className="board">
      <SideArea {...props} side={theirs} opponent onPile={setPile} />
      <div className="phase-track">
        <p>
          {props.finished
            ? `Turno ${view.turn}, duelo encerrado`
            : `Turno ${view.turn}, vez de ${props.names[view.turn_team]}`}
        </p>
        {/* Com a corrente aberta, a corrente fica no lugar das fases (a fase não muda no meio
            dela), na mesma altura: a mesa não pula. */}
        <div className="phase-slot">
          {props.chain && props.chain.length > 0 ? (
            <ChainStrip {...props} chain={props.chain} />
          ) : (
            <ol className="phase-list" aria-label="Fases do turno">
              {PHASES.map(([key, label]) => (
                <li
                  key={key}
                  aria-current={!props.finished && view.phase === key ? "step" : undefined}
                >
                  {label}
                </li>
              ))}
            </ol>
          )}
        </div>
        {props.center}
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
  // data-actionable só onde há carta para usar (o atributo some quando é falso).
  const lit = (place: string) => props.actionable?.has(`${team}-${place}`) || undefined;
  const open = (title: string, cards: HandCard[], location: number) => () =>
    props.onPile({
      title,
      cards: cards
        .map((card, index) => ({ card, place: `${team}-${location}-${index}` }))
        .reverse(),
    });
  const field = (
    <div className="field-grid">
      <div
        className="zone field-zone pile-field"
        role="group"
        aria-label={`Campo de ${name}`}
        data-actionable={lit("8-5")}
      >
        {side.field_spell && <CardView {...props} card={side.field_spell} place={`${team}-8-5`} />}
      </div>
      <ol className="zones monster-row" aria-label={`Monstros de ${name}`}>
        {side.monsters.map((card, index) => (
          <li
            key={index}
            className="zone"
            data-place={`${team}-4-${index}`}
            data-actionable={lit(`4-${index}`)}
          >
            {card && <CardView {...props} card={card} place={`${team}-4-${index}`} />}
          </li>
        ))}
      </ol>
      <ol className="zones spell-row" aria-label={`Magias e armadilhas de ${name}`}>
        {side.spells.map((card, index) => (
          <li
            key={index}
            className="zone"
            data-place={`${team}-8-${index}`}
            data-actionable={lit(`8-${index}`)}
          >
            {card && <CardView {...props} card={card} place={`${team}-8-${index}`} />}
          </li>
        ))}
      </ol>
      <PileButton
        {...props}
        className="pile-grave"
        place={`${team}-16`}
        lit={lit("16")}
        label={label("Cemitério", "Seu cemitério")}
        pile={side.grave}
        onOpen={open(label("Cemitério", "Seu cemitério"), side.grave, 16)}
      />
      <div
        className="zone pile pile-deck"
        role="group"
        data-actionable={lit("1")}
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
          lit={lit("64")}
          label="Seu Extra"
          pile={side.extra_cards}
          hideTop
          onOpen={open("Seu Extra", side.extra_cards, 64)}
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
        <li key={index} data-actionable={lit(`2-${index}`)}>
          <CardView {...props} card={card} place={`${team}-2-${index}`} />
        </li>
      ))}
    </ol>
  );
  const info = (
    <div className="side-info">
      <strong>{name}</strong>
      {props.emotes?.has(team) && (
        <span className="emote" role="status">
          {props.emotes.get(team)}
        </span>
      )}
      <span className="lp" data-lp={team}>
        PV {side.lp}
        <LpChange event={props.lpChanges?.get(team)} />
      </span>
      <button
        type="button"
        className="pile-banished"
        data-actionable={lit("32")}
        onClick={open(label("Cartas banidas", "Suas cartas banidas"), side.banished, 32)}
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
    place?: string;
    // Tem carta para usar nesta pilha (brilha).
    lit?: boolean;
    onOpen: () => void;
  },
) {
  const top = props.hideTop ? undefined : props.pile.at(-1)?.code;
  return (
    <button
      type="button"
      className={`zone pile ${props.className}`}
      data-place={props.place}
      data-actionable={props.lit}
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
              {props.pile.cards.map(({ card, place }) => (
                <li key={place} data-actionable={props.actionable?.has(place) || undefined}>
                  <PileCard
                    {...props}
                    card={card}
                    onShow={(code) => {
                      dialog.current?.close();
                      if (props.onCardAt) props.onCardAt(place, code);
                      else props.onCard(code);
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

function CardView(props: Props & { card: FieldCard | HandCard; place: string }) {
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
  const monster =
    "atk" in card && card.atk !== undefined && data?.card_type === "Monster" ? card : null;
  const label = [
    name,
    faceDown && "virada para baixo",
    defense && "em defesa",
    revealed && "revelada",
    monster && `ATK ${monster.atk}`,
    typeof monster?.def === "number" && `DEF ${monster.def}`,
  ];
  return (
    <>
      <button
        type="button"
        className={["card", defense && "defense", faceDown && "face-down", revealed && "revealed"]
          .filter(Boolean)
          .join(" ")}
        aria-label={label.filter(Boolean).join(", ")}
        onClick={() => (props.onCardAt ? props.onCardAt(props.place, code) : props.onCard(code))}
      >
        {data?.image !== undefined ? (
          <img src={imageUrl(data.image, "p")} alt="" width={56} height={82} decoding="async" />
        ) : (
          <span className="card-name">{name}</span>
        )}
      </button>
      {/* Na mesa vale o número da posição, como nos jogos oficiais: ATK em ataque, DEF em
          defesa. Os dois inteiros cabiam só cortados numa zona de celular; o nome lido traz
          os dois. Fica fora do botão para não girar junto com a carta em defesa. */}
      {monster && (
        <span className={defense ? "card-stats def" : "card-stats"} aria-hidden="true">
          {defense ? monster.def : monster.atk}
        </span>
      )}
    </>
  );
}

// O PV que mudou sobe e some acima do número (o histórico tem a linha para o leitor de
// tela). A chave é o evento: cada mudança nova é um elemento novo, e a animação roda de novo.
const LP_SIGNS: Record<string, string> = { damage: "−", cost: "−", recover: "+" };

function LpChange({ event }: { event?: DuelEvent }) {
  if (!event) return null;
  const kind = String(event.kind);
  return (
    <span key={event.id} className={`lp-change ${kind}`} aria-hidden="true">
      {LP_SIGNS[kind] ?? ""}
      {Number(event.amount).toLocaleString("pt-BR")}
    </span>
  );
}

// A corrente aberta, compacta, por cima do meio da mesa: o elo mais alto à direita, porque
// é ele que resolve primeiro. A lista inteira, com os textos, fica no histórico.
function ChainStrip(props: Props & { chain: ChainLink[] }) {
  return (
    <ol className="chain-strip" aria-label={`Corrente com ${props.chain.length} elos`}>
      {props.chain.map((link) => {
        const data = props.cards.get(link.code);
        const name = data ? displayName(data, props.language) : `Carta ${link.code}`;
        return (
          <li key={link.link} className={link.negated ? "negated" : undefined}>
            <span className="chain-number" aria-hidden="true">
              {link.link}
            </span>
            {data?.image !== undefined ? (
              <img src={imageUrl(data.image, "p")} alt="" width={28} height={41} decoding="async" />
            ) : (
              <span className="chain-face" aria-hidden="true" />
            )}
            <span className="visually-hidden">
              Elo {link.link}: {name}
              {link.negated && ", negado"}
            </span>
          </li>
        );
      })}
    </ol>
  );
}
