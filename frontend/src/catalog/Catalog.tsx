import { useMemo, useRef, useState } from "react";
import { EMPTY_FILTERS, matches, sortCards, type Filters } from "./cards.ts";
import { useCardDetail, useCatalog, usePackRarities } from "./data.ts";
import { CatalogFilters } from "./Filters.tsx";
import { RARITIES, label } from "./labels.ts";
import { useCardLanguage } from "./language.ts";
import { CardTile, Detail } from "./parts.tsx";
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
  const detail = useCardDetail(selected);
  const rarities = usePackRarities(pack).data ?? null;
  const panel = useRef<HTMLElement>(null);

  const results = useMemo(() => {
    if (!catalog.data || (pack !== "" && !rarities)) return [];
    const list = catalog.data.cards.filter(
      (card) => matches(card, filters) && (!rarities || rarities.has(card.id)),
    );
    return sortCards(list, filters, language);
  }, [catalog.data, filters, pack, rarities, language]);
  const packNames = useMemo(
    () => new Map(catalog.data?.packs.map((item) => [item.id, item.name])),
    [catalog.data],
  );

  function update(change: Partial<Filters>) {
    setFilters((old) => ({ ...old, ...change }));
    setShown(PAGE);
  }

  function select(id: number) {
    setSelected(id);
    const url = new URL(location.href);
    url.searchParams.set("carta", String(id));
    history.replaceState(null, "", url);
    if (matchMedia("(max-width: 959px)").matches) panel.current?.scrollIntoView({ block: "start" });
  }

  if (catalog.isError) {
    return (
      <main className="page catalog-page">
        <h1>Catálogo de cartas</h1>
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
        <h1>Catálogo de cartas</h1>
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
        language={language}
        onLanguage={setLanguage}
        onReset={() => {
          setFilters(EMPTY_FILTERS);
          setPack("");
          setShown(PAGE);
        }}
      />

      <div className="catalog-body">
        {selected > 0 && (
          <section className="card-detail" aria-labelledby="detail-title" ref={panel}>
            {detail.data ? (
              <Detail card={detail.data} language={language} packs={packNames} />
            ) : (
              <h2 id="detail-title">
                {detail.isError ? "Carta não encontrada." : "Carregando a carta…"}
              </h2>
            )}
          </section>
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
          {results.length > shown && (
            <button type="button" onClick={() => setShown((value) => value + PAGE)}>
              Mostrar mais
            </button>
          )}
        </section>
      </div>
    </main>
  );
}
