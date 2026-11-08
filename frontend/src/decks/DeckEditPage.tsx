import { useMemo, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Link, useLocation, useNavigate, useParams } from "react-router";
import { ApiError, request } from "../api.ts";
import { useSession } from "../account/session.ts";
import { displayName, type CardSummary, type Language, type Pack } from "../catalog/cards.ts";
import { useCardDetail, useCatalog } from "../catalog/data.ts";
import { Detail } from "../catalog/parts.tsx";
import { useCardLanguage } from "../catalog/language.ts";
import { useCollection } from "../collection/api.ts";
import { useDeck, type Deck } from "./api.ts";
import { Chest } from "./Chest.tsx";
import {
  SECTIONS,
  deckErrors,
  editDeck,
  sectionCount,
  type DeckEdit,
  type DeckRow,
  type Section,
} from "./deck.ts";

// Deck Edit (escopo 3.3 e 4): as seções do deck, a validação ao vivo e salvar.
export function DeckEditPage() {
  const id = Number(useParams().id);
  const user = useSession().data?.user;
  const deck = useDeck(id);
  const catalog = useCatalog();
  const collection = useCollection(Boolean(user));
  const [language, setLanguage] = useCardLanguage();

  if (deck.isError) {
    return (
      <main className="page narrow">
        <h1>Deck não encontrado</h1>
        <p>
          <Link to="/decks">Voltar para os decks</Link>
        </p>
      </main>
    );
  }
  if (!deck.data || !catalog.data || !collection.data) {
    return (
      <main className="page">
        <p role="status">Carregando o deck…</p>
      </main>
    );
  }

  const cards = new Map(catalog.data.cards.map((card) => [card.id, card]));
  const owned = new Map(collection.data.data.map((row) => [row.card_id, row.quantity]));
  return (
    <Editor
      key={deck.data.id}
      deck={deck.data}
      cards={cards}
      packs={catalog.data.packs}
      owned={owned}
      language={language}
      onLanguage={setLanguage}
    />
  );
}

type EditorProps = {
  deck: Deck;
  cards: Map<number, CardSummary>;
  packs: Pack[];
  owned: Map<number, number>;
  language: Language;
  onLanguage: (language: Language) => void;
};

function Editor({ deck, cards, packs, owned, language, onLanguage }: EditorProps) {
  const [rows, setRows] = useState<DeckRow[]>(deck.cards);
  const [selected, setSelected] = useState(0);
  const detail = useCardDetail(selected);
  const packNames = useMemo(() => new Map(packs.map((item) => [item.id, item.name])), [packs]);
  const cardList = useMemo(() => [...cards.values()], [cards]);
  const [name, setName] = useState(deck.name);
  const [section, setSection] = useState<Section>("main");
  const [confirmDelete, setConfirmDelete] = useState(false);
  const warnings: string[] =
    (useLocation().state as { warnings?: string[] } | null)?.warnings ?? [];
  const client = useQueryClient();
  const navigate = useNavigate();
  const errors = useMemo(
    () => deckErrors(rows, cards, owned, language),
    [rows, cards, owned, language],
  );
  const unsaved = name !== deck.name || JSON.stringify(rows) !== JSON.stringify(deck.cards);

  const save = useMutation({
    mutationFn: () =>
      request<{ data: Deck }>("PATCH", `/api/decks/${deck.id}`, { name, cards: rows }),
    onSuccess: ({ data }) => {
      client.setQueryData(["deck", deck.id], data);
      client.invalidateQueries({ queryKey: ["decks"] });
    },
  });
  const remove = useMutation({
    mutationFn: () => request("DELETE", `/api/decks/${deck.id}`),
    onSuccess: () => {
      client.invalidateQueries({ queryKey: ["decks"] });
      navigate("/decks");
    },
  });
  const edit = (change: DeckEdit) => setRows((old) => editDeck(old, change));
  const cardName = (cardId: number) => {
    const card = cards.get(cardId);
    return card ? displayName(card, language) : `Carta ${cardId}`;
  };

  return (
    <main className="page deck-page">
      <h1>{deck.name}</h1>
      {warnings.length > 0 && (
        <section aria-labelledby="warnings-title" className="warnings">
          <h2 id="warnings-title">Ficou de fora da importação</h2>
          <ul>
            {warnings.map((warning) => (
              <li key={warning}>{warning}</li>
            ))}
          </ul>
        </section>
      )}

      <div className="deck-layout">
        <Chest
          cards={cardList}
          packs={packs}
          owned={owned}
          rows={rows}
          language={language}
          onLanguage={onLanguage}
          selected={selected}
          onSelect={setSelected}
          onAdd={(cardId, to) => edit({ type: "add", cardId, section: to })}
        />
        <div className="deck-side">
          {selected > 0 && (
            <section className="card-detail" aria-labelledby="detail-title">
              {detail.data ? (
                <Detail card={detail.data} language={language} packs={packNames} />
              ) : (
                <h2 id="detail-title">Carregando a carta…</h2>
              )}
            </section>
          )}
          <section aria-labelledby="deck-title" className="deck-panel">
            <h2 id="deck-title">Deck</h2>
            <div className="form-field">
              <label htmlFor="deck-name">Nome do deck</label>
              <input
                id="deck-name"
                type="text"
                maxLength={40}
                value={name}
                onChange={(event) => setName(event.target.value)}
              />
            </div>

            <div className="sections" role="group" aria-label="Seção do deck">
              {(Object.keys(SECTIONS) as Section[]).map((item) => (
                <button
                  key={item}
                  type="button"
                  aria-pressed={section === item}
                  onClick={() => setSection(item)}
                >
                  {SECTIONS[item].title} ({sectionCount(rows, item)})
                </button>
              ))}
            </div>

            <ul className="deck-rows" aria-label={SECTIONS[section].title}>
              {rows
                .filter((row) => row.section === section)
                .map((row) => (
                  <li key={`${row.card_id}-${row.section}`}>
                    <span className="row-name">
                      {row.quantity}× {cardName(row.card_id)}
                    </span>
                    <button
                      type="button"
                      aria-label={`Tirar uma cópia de ${cardName(row.card_id)}`}
                      onClick={() => edit({ type: "remove", cardId: row.card_id, section })}
                    >
                      −
                    </button>
                    <button
                      type="button"
                      aria-label={`Pôr mais uma cópia de ${cardName(row.card_id)}`}
                      onClick={() => edit({ type: "add", cardId: row.card_id, section })}
                    >
                      +
                    </button>
                    {section === "main" && (
                      <label className="choice">
                        <input
                          type="checkbox"
                          checked={row.destiny}
                          onChange={() => edit({ type: "destiny", cardId: row.card_id })}
                        />
                        Destiny
                      </label>
                    )}
                    {section !== "extra" && (
                      <button
                        type="button"
                        aria-label={`Mandar uma cópia de ${cardName(row.card_id)} para o ${section === "main" ? "Side" : "Main"}`}
                        onClick={() =>
                          edit({
                            type: "move",
                            cardId: row.card_id,
                            from: section,
                            to: section === "main" ? "side" : "main",
                          })
                        }
                      >
                        {section === "main" ? "→ Side" : "→ Main"}
                      </button>
                    )}
                  </li>
                ))}
            </ul>

            <div aria-live="polite">
              {errors.length === 0 ? (
                <p className="ok">Deck válido.</p>
              ) : (
                <ul className="deck-errors" aria-label="Problemas do deck">
                  {errors.map((error) => (
                    <li key={error}>{error}</li>
                  ))}
                </ul>
              )}
            </div>

            <p className="deck-actions">
              <button
                type="button"
                className="cta"
                disabled={save.isPending || !unsaved}
                onClick={() => save.mutate()}
              >
                {save.isPending ? "Salvando…" : "Salvar"}
              </button>
              {save.isSuccess && !unsaved && <span role="status">Deck salvo.</span>}
              {save.error && (
                <span role="alert" className="form-error">
                  {save.error instanceof ApiError
                    ? save.error.message
                    : "Sem conexão. Tente de novo."}
                </span>
              )}
            </p>
            <p className="deck-actions">
              {unsaved ? (
                <span className="muted">Salve para exportar.</span>
              ) : (
                <>
                  <a href={`/api/decks/${deck.id}/export.ydk`} download>
                    Exportar .ydk
                  </a>
                  <a href={`/api/decks/${deck.id}/export.txt`} download>
                    Exportar texto
                  </a>
                </>
              )}
              <button
                type="button"
                className="danger"
                disabled={remove.isPending}
                onClick={() => (confirmDelete ? remove.mutate() : setConfirmDelete(true))}
              >
                {confirmDelete ? "Confirmar: apagar o deck" : "Apagar deck"}
              </button>
            </p>
          </section>
        </div>
      </div>
    </main>
  );
}
