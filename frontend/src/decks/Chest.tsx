import { startTransition, useDeferredValue, useMemo, useState } from "react";
import {
  EMPTY_FILTERS,
  displayName,
  filtersChanged,
  matches,
  sortCards,
  type CardSummary,
  type Filters,
  type Language,
  type Pack,
} from "../catalog/cards.ts";
import { usePackRarities } from "../catalog/data.ts";
import { useCollection, useMarkSeen } from "../collection/api.ts";
import { CatalogFilters } from "../catalog/Filters.tsx";
import { CardTile } from "../catalog/parts.tsx";
import { addBlocked, copies, goesToExtra, type DeckRow, type Section } from "./deck.ts";
import { allowDrop, dragCard, droppedRow } from "./drag.ts";

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
  onRemove: (cardId: number, section: Section) => void;
};

// Baú do Deck Edit (escopo 4): as cartas para pôr no deck, com os filtros do catálogo.
// Fusão e Sincro vão para o Extra; o resto, para o Main.
// A carta ganha na loja ou numa missão aparece como nova até o jogador abrir o detalhe dela
// (GXP-42), e dá para ver só as novas ou pôr as mais recentes primeiro.
export function Chest(props: Props) {
  const { owned, rows, language } = props;
  const [filters, setFilters] = useState<Filters>(EMPTY_FILTERS);
  const [pack, setPack] = useState("");
  const [onlyOwned, setOnlyOwned] = useState(true);
  const [onlyNew, setOnlyNew] = useState(false);
  const [recentFirst, setRecentFirst] = useState(false);
  const [shown, setShown] = useState(PAGE);
  const rarities = usePackRarities(pack).data ?? null;
  const collection = useCollection(true).data?.data;
  const markSeen = useMarkSeen();
  const fresh = useMemo(
    () => new Set(collection?.filter((row) => row.new).map((row) => row.card_id)),
    [collection],
  );
  const obtained = useMemo(
    () => new Map(collection?.map((row) => [row.card_id, row.obtained_at])),
    [collection],
  );
  // "Só as novas" mostra as que eram novas quando o filtro foi ligado: abrir o detalhe de uma
  // carta não a faz sumir da lista na mesma hora.
  const [newShown, setNewShown] = useState<Set<number>>(new Set());

  // A lista filtra com o valor "atrasado" dos filtros: o campo responde na hora a cada tecla e
  // a lista vem logo atrás, sem travar a digitação no celular.
  const deferred = useDeferredValue(filters);
  const results = useMemo(() => {
    if (pack !== "" && !rarities) return [];
    const list = props.cards.filter(
      (card) =>
        (!onlyOwned || owned.has(card.id)) &&
        (!onlyNew || newShown.has(card.id)) &&
        matches(card, deferred) &&
        (!rarities || rarities.has(card.id)),
    );
    const sorted = sortCards(list, deferred, language);
    if (!recentFirst) return sorted;
    // Mais recentes primeiro; as que o jogador não tem vão para o fim. O sort é estável: no
    // mesmo dia, vale a ordem escolhida nos filtros.
    return sorted.sort((a, b) =>
      (obtained.get(b.id) ?? "").localeCompare(obtained.get(a.id) ?? ""),
    );
  }, [
    props.cards,
    onlyOwned,
    onlyNew,
    newShown,
    owned,
    deferred,
    pack,
    rarities,
    language,
    recentFirst,
    obtained,
  ]);

  const reset = () => setShown(PAGE);

  return (
    <section
      aria-labelledby="chest-title"
      className="chest"
      onDragOver={(event) => allowDrop(event, "baú")}
      onDrop={(event) => {
        const row = droppedRow(event);
        if (row) props.onRemove(row.cardId, row.section);
      }}
    >
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
          setOnlyNew(false);
          setRecentFirst(false);
          reset();
        }}
        canReset={filtersChanged(filters, pack) || !onlyOwned || onlyNew || recentFirst}
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
        <label className="choice">
          <input
            type="checkbox"
            checked={recentFirst}
            onChange={(event) => {
              setRecentFirst(event.target.checked);
              reset();
            }}
          />
          Mais recentes primeiro
        </label>
      </CatalogFilters>

      {(fresh.size > 0 || onlyNew) && (
        <p className="chest-new">
          {fresh.size > 0
            ? `Você tem ${fresh.size} ${fresh.size === 1 ? "carta nova" : "cartas novas"}.`
            : "Você já viu todas as cartas novas."}
          <button
            type="button"
            aria-pressed={onlyNew}
            onClick={() => {
              setNewShown(new Set(fresh));
              setOnlyNew(!onlyNew);
              reset();
            }}
          >
            {onlyNew ? "Ver todas" : "Ver só as novas"}
          </button>
          {fresh.size > 0 && (
            <button
              type="button"
              onClick={() => {
                markSeen();
                setOnlyNew(false);
              }}
            >
              Marcar todas como vistas
            </button>
          )}
        </p>
      )}

      <p role="status">{`${results.length} ${results.length === 1 ? "carta" : "cartas"}`}</p>
      <ul className="card-grid">
        {results.slice(0, shown).map((card) => {
          const name = displayName(card, language);
          const deckSection = goesToExtra(card) ? "extra" : "main";
          const reason = addBlocked(rows, card.id, deckSection);
          const reasonId = `chest-reason-${card.id}`;
          return (
            <li
              key={card.id}
              className="chest-item"
              draggable
              onDragStart={(event) => dragCard(event, card.id)}
            >
              <CardTile
                card={card}
                language={language}
                selected={props.selected === card.id}
                onSelect={() => {
                  props.onSelect(card.id);
                  if (fresh.has(card.id)) markSeen([card.id]);
                }}
              >
                <span className="badge">
                  Tenho {owned.get(card.id) ?? 0} · no deck {copies(rows, card.id)}
                </span>
                {fresh.has(card.id) && <strong className="badge new-card">Nova</strong>}
                {reason && (
                  <span id={reasonId} className="chest-reason">
                    {reason}
                  </span>
                )}
              </CardTile>
              <span className="chest-actions">
                <button
                  type="button"
                  aria-label={`Pôr ${name} no ${deckSection === "extra" ? "Extra" : "Main"} Deck`}
                  disabled={Boolean(reason)}
                  aria-describedby={reason ? reasonId : undefined}
                  onClick={() => props.onAdd(card.id, deckSection)}
                >
                  + {deckSection === "extra" ? "Extra" : "Main"}
                </button>
              </span>
            </li>
          );
        })}
      </ul>
      {/* Em transição: o toque responde na hora e as próximas cartas vêm logo atrás. */}
      {results.length > shown && (
        <button
          type="button"
          onClick={() => startTransition(() => setShown((value) => value + PAGE))}
        >
          Mostrar mais
        </button>
      )}
    </section>
  );
}
