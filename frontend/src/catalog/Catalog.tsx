import { useEffect, useMemo, useState } from "react";
import {
  EMPTY_FILTERS,
  displayName,
  frame,
  matches,
  sortCards,
  typeLine,
  type CardSummary,
  type Filters,
} from "./cards.ts";
import { ATTRIBUTES, BANLIST, CARD_TYPES, label } from "./labels.ts";

const PAGE = 60; // cartas por vez na lista; "Mostrar mais" traz as próximas

async function getData<T>(url: string): Promise<T> {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`${url}: ${response.status}`);
  return ((await response.json()) as { data: T }).data;
}

function Stats({ card }: { card: CardSummary }) {
  if (card.card_type !== "Monster") return null;
  return (
    <p className="stats">
      {label(ATTRIBUTES, card.attribute)} · ★ {card.level} · ATK {card.atk ?? "?"} / DEF{" "}
      {card.def ?? "?"}
    </p>
  );
}

function Choices(props: {
  name: string;
  title: string;
  value: string;
  options: Record<string, string>;
  onChange: (value: string) => void;
}) {
  return (
    <fieldset className="field wide">
      <legend>{props.title}</legend>
      {Object.entries(props.options).map(([value, text]) => (
        <label key={value} className="choice">
          <input
            type="radio"
            name={props.name}
            value={value}
            checked={props.value === value}
            onChange={() => props.onChange(value)}
          />
          {text}
        </label>
      ))}
    </fieldset>
  );
}

// Página /cartas: o pool inteiro, com busca e filtros. A lista chega numa resposta só (ADR
// 0007) e os filtros rodam aqui, sem ir à rede a cada letra.
export function Catalog() {
  const [attempt, setAttempt] = useState(0);
  const [cards, setCards] = useState<CardSummary[] | null>(null);
  const [failed, setFailed] = useState(false);
  const [filters, setFilters] = useState<Filters>(EMPTY_FILTERS);
  const [shown, setShown] = useState(PAGE);

  useEffect(() => {
    getData<CardSummary[]>("/api/cards")
      .then(setCards)
      .catch(() => setFailed(true));
  }, [attempt]);

  const results = useMemo(
    () =>
      sortCards(
        (cards ?? []).filter((card) => matches(card, filters)),
        filters,
        "pt",
      ),
    [cards, filters],
  );

  function update(change: Partial<Filters>) {
    setFilters((old) => ({ ...old, ...change }));
    setShown(PAGE);
  }

  if (failed) {
    return (
      <main className="page catalog-page">
        <h1>Catálogo de cartas</h1>
        <p role="alert">Não deu para carregar as cartas.</p>
        <button
          type="button"
          onClick={() => {
            setFailed(false);
            setAttempt((value) => value + 1);
          }}
        >
          Tentar de novo
        </button>
      </main>
    );
  }

  return (
    <main className="page catalog-page">
      <header className="catalog-header">
        <p className="eyebrow">
          <a href="/">GX Project</a>
        </p>
        <h1>Catálogo de cartas</h1>
      </header>

      <form
        className="filters"
        role="search"
        aria-label="Filtros do catálogo"
        onSubmit={(event) => event.preventDefault()}
      >
        <div className="field wide">
          <label htmlFor="q">Nome</label>
          <input
            id="q"
            type="search"
            enterKeyHint="search"
            autoCorrect="off"
            autoCapitalize="off"
            spellCheck={false}
            value={filters.q}
            onChange={(event) => update({ q: event.target.value })}
          />
        </div>
        <Choices
          name="card-type"
          title="Tipo de carta"
          value={filters.cardType}
          options={{ "": "Todas", ...CARD_TYPES }}
          onChange={(value) => update({ cardType: value })}
        />
      </form>

      <section className="results" aria-label="Cartas">
        <p role="status">
          {cards
            ? `${results.length} ${results.length === 1 ? "carta" : "cartas"}`
            : "Carregando as cartas…"}
        </p>
        <ul className="card-grid">
          {results.slice(0, shown).map((card) => (
            <li key={card.id} className={`card-tile frame-${frame(card)}`}>
              <strong>{displayName(card, "pt")}</strong>
              <span className="type-line">{typeLine(card)}</span>
              <Stats card={card} />
              {card.banlist && <span className="badge">{label(BANLIST, card.banlist)}</span>}
            </li>
          ))}
        </ul>
        {results.length > shown && (
          <button type="button" onClick={() => setShown((value) => value + PAGE)}>
            Mostrar mais
          </button>
        )}
      </section>
    </main>
  );
}
