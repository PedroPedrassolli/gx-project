import { useMemo, useState } from "react";
import {
  EMPTY_FILTERS,
  displayName,
  matches,
  sortCards,
  type CardSummary,
  type Filters,
  type Language,
  type Pack,
} from "../catalog/cards.ts";
import { usePackRarities } from "../catalog/data.ts";
import { CatalogFilters } from "../catalog/Filters.tsx";
import { CardTile } from "../catalog/parts.tsx";
import { copies, goesToExtra, type DeckRow, type Section } from "./deck.ts";

const PAGE = 60;

type Props = {
  cards: CardSummary[];
  packs: Pack[];
  owned: Map<number, number>;
  rows: DeckRow[];
  language: Language;
  onLanguage: (language: Language) => void;
  selected: number;
  onSelect: (id: number) => void;
  onAdd: (cardId: number, section: Section) => void;
};

// Baú do Deck Edit (escopo 4): as cartas para pôr no deck, com os filtros do catálogo.
// Fusão e Sincro vão para o Extra; o resto, para o Main. Qualquer uma pode ir para o Side.
export function Chest(props: Props) {
  const { owned, rows, language } = props;
  const [filters, setFilters] = useState<Filters>(EMPTY_FILTERS);
  const [pack, setPack] = useState("");
  const [onlyOwned, setOnlyOwned] = useState(true);
  const [shown, setShown] = useState(PAGE);
  const rarities = usePackRarities(pack).data ?? null;

  const results = useMemo(() => {
    if (pack !== "" && !rarities) return [];
    const list = props.cards.filter(
      (card) =>
        (!onlyOwned || owned.has(card.id)) &&
        matches(card, filters) &&
        (!rarities || rarities.has(card.id)),
    );
    return sortCards(list, filters, language);
  }, [props.cards, onlyOwned, owned, filters, pack, rarities, language]);

  const reset = () => setShown(PAGE);

  return (
    <section aria-labelledby="chest-title" className="chest">
      <h2 id="chest-title">Baú</h2>
      <CatalogFilters
        title="Filtros do baú"
        filters={filters}
        onChange={(change) => {
          setFilters((old) => ({ ...old, ...change }));
          reset();
        }}
        pack={pack}
        onPack={(value) => {
          setPack(value);
          reset();
        }}
        packs={props.packs}
        language={language}
        onLanguage={props.onLanguage}
        onReset={() => {
          setFilters(EMPTY_FILTERS);
          setPack("");
          setOnlyOwned(true);
          reset();
        }}
      >
        <label className="choice only-owned">
          <input
            type="checkbox"
            checked={onlyOwned}
            onChange={(event) => {
              setOnlyOwned(event.target.checked);
              reset();
            }}
          />
          Só as que tenho
        </label>
      </CatalogFilters>

      <p role="status">{`${results.length} ${results.length === 1 ? "carta" : "cartas"}`}</p>
      <ul className="card-grid">
        {results.slice(0, shown).map((card) => {
          const name = displayName(card, language);
          const deckSection = goesToExtra(card) ? "extra" : "main";
          return (
            <li key={card.id} className="chest-item">
              <CardTile
                card={card}
                language={language}
                selected={props.selected === card.id}
                onSelect={() => props.onSelect(card.id)}
              >
                <span className="badge">
                  Tenho {owned.get(card.id) ?? 0} · no deck {copies(rows, card.id)}
                </span>
              </CardTile>
              <span className="chest-actions">
                <button
                  type="button"
                  aria-label={`Pôr ${name} no ${deckSection === "extra" ? "Extra" : "Main"} Deck`}
                  onClick={() => props.onAdd(card.id, deckSection)}
                >
                  + {deckSection === "extra" ? "Extra" : "Main"}
                </button>
                <button
                  type="button"
                  aria-label={`Pôr ${name} no Side Deck`}
                  onClick={() => props.onAdd(card.id, "side")}
                >
                  + Side
                </button>
              </span>
            </li>
          );
        })}
      </ul>
      {results.length > shown && (
        <button type="button" onClick={() => setShown((value) => value + PAGE)}>
          Mostrar mais
        </button>
      )}
    </section>
  );
}
