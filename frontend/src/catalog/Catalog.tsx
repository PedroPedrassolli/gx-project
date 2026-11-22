import { startTransition, useDeferredValue, useMemo, useState } from "react";
import { EMPTY_FILTERS, filtersChanged, matches, sortCards, type Filters } from "./cards.ts";
import { CardPanel, WIDE, useMediaQuery } from "./CardPanel.tsx";
import { NO_PACKS, useCatalog, usePackRarities } from "./data.ts";
import { CatalogFilters } from "./Filters.tsx";
import { RARITIES, label } from "./labels.ts";
import { useCardLanguage } from "./language.ts";
import { CardTile } from "./parts.tsx";
import { usePageTitle } from "../pageTitle.ts";

const PAGE = 60; // cartas por vez na lista; "Mostrar mais" traz as próximas

export function Catalog() {
  usePageTitle("Cartas");
  const catalog = useCatalog();
  const [filters, setFilters] = useState<Filters>(EMPTY_FILTERS);
  const [pack, setPack] = useState("");
  const [language, setLanguage] = useCardLanguage();
  const [shown, setShown] = useState(PAGE);
  const [selected, setSelected] = useState(
    () => Number(new URLSearchParams(location.search).get("carta")) || 0,
  );
  const rarities = usePackRarities(pack).data ?? null;
  const wide = useMediaQuery(WIDE);

  // A lista filtra com o valor "atrasado" dos filtros: o campo responde na hora a cada tecla e
  // a lista vem logo atrás, sem travar a digitação no celular.
  const deferred = useDeferredValue(filters);
  const results = useMemo(() => {
    if (!catalog.data || (pack !== "" && !rarities)) return [];
    const list = catalog.data.cards.filter(
      (card) => matches(card, deferred) && (!rarities || rarities.has(card.id)),
    );
    return sortCards(list, deferred, language);
  }, [catalog.data, deferred, pack, rarities, language]);
  const packNames = catalog.data?.packNames ?? NO_PACKS;

  function update(change: Partial<Filters>) {
    setFilters((old) => ({ ...old, ...change }));
    setShown(PAGE);
  }

  // A carta escolhida fica no endereço (?carta=), para voltar a ela ou mandar o link.
  function select(id: number) {
    setSelected(id);
    const url = new URL(location.href);
    if (id > 0) url.searchParams.set("carta", String(id));
    else url.searchParams.delete("carta");
    history.replaceState(null, "", url);
  }

  // Só sem nenhuma cópia: com a guardada da última visita, a lista segue na tela.
  if (catalog.isError && !catalog.data) {
    return (
      <main className="page catalog-page">
        <h1>Cartas</h1>
        <p role="alert">Não deu para carregar as cartas.</p>
        <button type="button" onClick={() => catalog.refetch()}>
          Tentar de novo
        </button>
      </main>
    );
  }

  return (
    <main className="page catalog-page">
      <header className="catalog-header">
        <h1>Cartas</h1>
      </header>

      <CatalogFilters
        title="Filtros do catálogo"
        filters={filters}
        onChange={update}
        pack={pack}
        onPack={(value) => {
          setPack(value);
          setShown(PAGE);
        }}
        packs={catalog.data?.packs ?? []}
        results={catalog.data ? results.length : undefined}
        onReset={() => {
          setFilters(EMPTY_FILTERS);
          setPack("");
          setShown(PAGE);
        }}
        canReset={filtersChanged(filters, pack)}
      />

      <div className="catalog-body">
        {selected > 0 && (
          <CardPanel
            cardId={selected}
            language={language}
            onLanguage={setLanguage}
            packs={packNames}
            wide={wide}
            onClose={() => select(0)}
          />
        )}
        <section className="results" aria-label="Cartas">
          <p role="status">
            {catalog.data
              ? `${results.length} ${results.length === 1 ? "carta" : "cartas"}`
              : "Carregando as cartas…"}
          </p>
          <ul className="card-grid">
            {results.slice(0, shown).map((card) => (
              <li key={card.id}>
                <CardTile
                  card={card}
                  language={language}
                  selected={selected === card.id}
                  onSelect={() => select(card.id)}
                >
                  {rarities && (
                    <span className="badge">{label(RARITIES, rarities.get(card.id))}</span>
                  )}
                </CardTile>
              </li>
            ))}
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
      </div>
    </main>
  );
}
