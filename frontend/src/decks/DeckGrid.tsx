import { displayName, type CardSummary, type Language } from "../catalog/cards.ts";
import { CardTile } from "../catalog/parts.tsx";
import { dragRow } from "./drag.ts";
import {
  SECTIONS,
  addBlocked,
  copies,
  deckOrder,
  goesToExtra,
  sectionCount,
  sectionFull,
  typeCounts,
  type DeckEdit,
  type DeckRow,
  type Section,
} from "./deck.ts";

// O deck no Deck Edit (GXP-132): cada seção é uma grade de cartas, como a coleção, com as
// cópias por cima da imagem e os botões embaixo. Tocar na carta abre o detalhe.

type SectionProps = {
  section: Section;
  rows: DeckRow[];
  cards: Map<number, CardSummary>;
  language: Language;
  selected: number;
  onSelect: (cardId: number) => void;
  onEdit: (edit: DeckEdit) => void;
};

export function DeckSection(props: SectionProps) {
  const { section, rows, cards } = props;
  const { title } = SECTIONS[section];
  const list = deckOrder(
    rows.filter((row) => row.section === section),
    cards,
    props.language,
  );
  return (
    <section aria-labelledby={`${section}-title`} className="deck-section">
      <div className="section-head">
        <h3 id={`${section}-title`}>
          {title} <span className="count">{sectionCount(rows, section)}</span>
        </h3>
        {section === "main" && <TypeCounts counts={typeCounts(rows, cards, section)} />}
      </div>
      {sectionFull(rows, section) && (
        <p className="hint">{title} cheio: tire uma carta para pôr outra.</p>
      )}
      {list.length === 0 ? (
        <p className="muted">
          {section === "main"
            ? "Nenhuma carta ainda: ponha as do baú."
            : "Nenhuma carta de Fusão ou Sincro."}
        </p>
      ) : (
        <ul className="card-grid deck-grid" aria-label={title}>
          {list.map((row) => (
            <DeckCard key={row.card_id} row={row} {...props} />
          ))}
        </ul>
      )}
    </section>
  );
}

// Monstros, magias e armadilhas, cada um com a cor da moldura (o Main Deck do jogo mostra
// essa conta em cima).
const TYPES = [
  { type: "Monster", one: "monstro", many: "monstros", frame: "effect" },
  { type: "Spell", one: "magia", many: "magias", frame: "spell" },
  { type: "Trap", one: "armadilha", many: "armadilhas", frame: "trap" },
] as const;

function TypeCounts({ counts }: { counts: ReturnType<typeof typeCounts> }) {
  return (
    <ul className="type-counts" aria-label="Monstros, magias e armadilhas">
      {TYPES.map(({ type, one, many, frame }) => (
        <li key={type} className={`frame-${frame}`}>
          {counts[type]} {counts[type] === 1 ? one : many}
        </li>
      ))}
    </ul>
  );
}

function DeckCard({ row, ...props }: SectionProps & { row: DeckRow }) {
  const card = props.cards.get(row.card_id);
  const name = card ? displayName(card, props.language) : `Carta ${row.card_id}`;
  const blocked = addBlocked(props.rows, row.card_id, row.section);
  const reasonId = `deck-reason-${row.section}-${row.card_id}`;
  const change = (type: "add" | "remove") =>
    props.onEdit({ type, cardId: row.card_id, section: row.section });
  return (
    <li
      className="deck-card"
      draggable
      onDragStart={(event) => dragRow(event, row.card_id, row.section)}
    >
      {card ? (
        <CardTile
          card={card}
          language={props.language}
          selected={props.selected === row.card_id}
          onSelect={() => props.onSelect(row.card_id)}
        >
          {/* O "×2" é para os olhos; o leitor de tela ouve "2 cópias" no nome da carta. */}
          <span className="badge copies">
            <span aria-hidden="true">×{row.quantity}</span>
            <span className="visually-hidden">{` ${row.quantity} ${row.quantity === 1 ? "cópia" : "cópias"}`}</span>
          </span>
        </CardTile>
      ) : (
        <span className="tile-name">{name}</span>
      )}
      <span className="stepper">
        <button
          type="button"
          aria-label={`Tirar uma cópia de ${name}`}
          onClick={() => change("remove")}
        >
          −
        </button>
        <button
          type="button"
          aria-label={`Pôr mais uma cópia de ${name}`}
          disabled={Boolean(blocked)}
          aria-describedby={blocked ? reasonId : undefined}
          onClick={() => change("add")}
        >
          +
        </button>
      </span>
      {blocked && (
        <span id={reasonId} className="visually-hidden">
          {blocked}
        </span>
      )}
      {row.section === "main" && (
        <Destiny
          checked={row.destiny}
          onChange={() => props.onEdit({ type: "destiny", cardId: row.card_id })}
        />
      )}
    </li>
  );
}

// Destiny é uma marca da carta no Main Deck (escopo 3.3): uma pílula que acende.
function Destiny(props: { checked: boolean; onChange: () => void }) {
  return (
    <label className="choice destiny">
      <input type="checkbox" checked={props.checked} onChange={props.onChange} />
      Destiny
    </label>
  );
}

type ActionsProps = {
  card: CardSummary;
  rows: DeckRow[];
  owned: number;
  onEdit: (edit: DeckEdit) => void;
};

// Os botões do deck no rodapé do detalhe da carta: ler a carta e já pôr ou tirar, sem fechar.
export function CardActions({ card, rows, owned, onEdit }: ActionsProps) {
  const section = goesToExtra(card) ? "extra" : "main";
  const row = rows.find((item) => item.card_id === card.id && item.section === section);
  const blocked = addBlocked(rows, card.id, section);
  return (
    <div className="card-actions">
      <p className="card-actions-head">
        <span>
          Você tem {owned}. No deck: {copies(rows, card.id)}.
        </span>
        {row && section === "main" && (
          <Destiny
            checked={row.destiny}
            onChange={() => onEdit({ type: "destiny", cardId: card.id })}
          />
        )}
      </p>
      <p className="actions">
        <button
          type="button"
          className="cta"
          disabled={Boolean(blocked)}
          aria-describedby={blocked ? "card-actions-reason" : undefined}
          onClick={() => onEdit({ type: "add", cardId: card.id, section })}
        >
          Pôr no {SECTIONS[section].title}
        </button>
        {row && (
          <button
            type="button"
            onClick={() => onEdit({ type: "remove", cardId: card.id, section })}
          >
            Tirar uma cópia
          </button>
        )}
      </p>
      {blocked && (
        <p id="card-actions-reason" className="hint">
          {blocked}
        </p>
      )}
    </div>
  );
}
