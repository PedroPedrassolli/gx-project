import { useMemo, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Link, useLocation, useNavigate, useParams } from "react-router";
import { ApiError, request } from "../api.ts";
import { useSession } from "../account/session.ts";
import type { CardSummary, Language, Pack } from "../catalog/cards.ts";
import { CardPanel } from "../catalog/CardPanel.tsx";
import { useCatalog } from "../catalog/data.ts";
import { useCardLanguage } from "../catalog/language.ts";
import { useCollection } from "../collection/api.ts";
import { useDeck, type Deck } from "./api.ts";
import { Chest } from "./Chest.tsx";
import { CardActions, DeckSection } from "./DeckGrid.tsx";
import { allowDrop, droppedCard } from "./drag.ts";
import {
  deckErrors,
  editDeck,
  goesToExtra,
  sectionCount,
  type DeckEdit,
  type DeckRow,
} from "./deck.ts";
import { usePageTitle } from "../pageTitle.ts";

// Deck Edit (escopo 3.3 e 4): o deck em grade, o baú, a validação ao vivo e salvar.
export function DeckEditPage() {
  usePageTitle("Editar deck");
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

  const cards = catalog.data.byId;
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
  // No celular, o deck e o baú são abas; no computador, ficam lado a lado e a aba some.
  const [tab, setTab] = useState<"deck" | "chest">("deck");
  const packNames = useMemo(() => new Map(packs.map((item) => [item.id, item.name])), [packs]);
  const cardList = useMemo(() => [...cards.values()], [cards]);
  const [name, setName] = useState(deck.name);
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
  // A carta que cai no deck vai para a seção dela: Fusão e Sincro no Extra, o resto no Main.
  const drop = (cardId: number) => {
    const card = cards.get(cardId);
    if (card) edit({ type: "add", cardId, section: goesToExtra(card) ? "extra" : "main" });
  };
  const selectedCard = cards.get(selected);

  return (
    <main className="page deck-page">
      <h1>{deck.name}</h1>
      {/* Presa no topo enquanto a página rola: a troca de aba (no celular) e o Salvar. */}
      <div className="deck-bar">
        <div className="segmented deck-tabs" role="group" aria-label="Deck ou baú">
          <button type="button" aria-pressed={tab === "deck"} onClick={() => setTab("deck")}>
            Deck <span className="count">{sectionCount(rows, "main")}</span>
          </button>
          <button type="button" aria-pressed={tab === "chest"} onClick={() => setTab("chest")}>
            Baú
          </button>
        </div>
        <button
          type="button"
          className="cta"
          disabled={save.isPending || !unsaved}
          onClick={() => save.mutate()}
        >
          {save.isPending ? "Salvando…" : unsaved ? "Salvar" : "Salvo"}
        </button>
        <span role="status" className="visually-hidden">
          {save.isSuccess && !unsaved ? "Deck salvo." : ""}
        </span>
      </div>
      {save.error && (
        <p role="alert" className="form-error deck-error">
          {save.error instanceof ApiError ? save.error.message : "Sem conexão. Tente de novo."}
        </p>
      )}
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

      <div className="deck-layout" data-tab={tab}>
        <section
          aria-labelledby="deck-title"
          className="deck-panel"
          onDragOver={(event) => allowDrop(event, "deck")}
          onDrop={(event) => {
            const cardId = droppedCard(event);
            if (cardId) drop(cardId);
          }}
        >
          <h2 id="deck-title" className="panel-title">
            Deck
          </h2>
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

          {(["main", "extra"] as const).map((section) => (
            <DeckSection
              key={section}
              section={section}
              rows={rows}
              cards={cards}
              language={language}
              selected={selected}
              onSelect={setSelected}
              onEdit={edit}
            />
          ))}

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

        <Chest
          cards={cardList}
          packs={packs}
          owned={owned}
          rows={rows}
          language={language}
          selected={selected}
          onSelect={setSelected}
          onAdd={(cardId, to) => edit({ type: "add", cardId, section: to })}
          onRemove={(cardId, from) => edit({ type: "remove", cardId, section: from })}
        />
      </div>

      {/* O detalhe abre por cima, em qualquer tela, com os botões do deck para a carta. */}
      {selected > 0 && (
        <CardPanel
          cardId={selected}
          language={language}
          onLanguage={onLanguage}
          packs={packNames}
          wide={false}
          onClose={() => setSelected(0)}
        >
          {selectedCard && (
            <CardActions
              card={selectedCard}
              rows={rows}
              owned={owned.get(selected) ?? 0}
              onEdit={edit}
            />
          )}
        </CardPanel>
      )}
    </main>
  );
}
