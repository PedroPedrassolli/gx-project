import { useMemo, useState } from "react";
import { Link } from "react-router";
import { useSession } from "../account/session.ts";
import { EMPTY_FILTERS, matches, sortCards, type Filters } from "../catalog/cards.ts";
import { useCardDetail, useCatalog, usePackRarities } from "../catalog/data.ts";
import { CatalogFilters } from "../catalog/Filters.tsx";
import { useCardLanguage } from "../catalog/language.ts";
import { CardTile, Detail } from "../catalog/parts.tsx";
import { useCollection, type Progress } from "./api.ts";
import { usePageTitle } from "../pageTitle.ts";

const PAGE = 60;
const percent = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 1 });

function progressText({ owned, cards, percent: value }: Progress) {
  return `${owned} de ${cards} (${percent.format(value)}%)`;
}

// Coleção do jogador (escopo 3.2 e 4): o que ele tem, quantas cópias e quanto falta do
// pool e de cada pacote (essa porcentagem libera pacotes na loja, na F4).
export function CollectionPage() {
  usePageTitle("Coleção");
  const session = useSession();
  const user = session.data?.user;
  const catalog = useCatalog();
  const collection = useCollection(Boolean(user));
  const [filters, setFilters] = useState<Filters>(EMPTY_FILTERS);
  const [pack, setPack] = useState("");
  const [language, setLanguage] = useCardLanguage();
  const [shown, setShown] = useState(PAGE);
  const [selected, setSelected] = useState(0);
  const detail = useCardDetail(selected);
  const rarities = usePackRarities(pack).data ?? null;

  const owned = useMemo(
    () => new Map(collection.data?.data.map((row) => [row.card_id, row.quantity])),
    [collection.data],
  );
  const results = useMemo(() => {
    if (!catalog.data || (pack !== "" && !rarities)) return [];
    const list = catalog.data.cards.filter(
      (card) =>
        owned.has(card.id) && matches(card, filters) && (!rarities || rarities.has(card.id)),
    );
    return sortCards(list, filters, language);
  }, [catalog.data, owned, filters, pack, rarities, language]);
  const packNames = useMemo(
    () => new Map(catalog.data?.packs.map((item) => [item.id, item.name])),
    [catalog.data],
  );

  if (session.isSuccess && !user) {
    return (
      <main className="page narrow">
        <h1>Coleção</h1>
        <p>
          <Link to="/entrar">Entre na sua conta</Link> para ver a sua coleção.
        </p>
      </main>
    );
  }

  const meta = collection.data?.meta;
  return (
    <main className="page catalog-page">
      <header className="catalog-header">
        <h1>Coleção</h1>
      </header>

      {meta && (
        <section aria-labelledby="progress-title" className="progress">
          <h2 id="progress-title">Você tem {progressText(meta.total)} cartas do jogo</h2>
          <details>
            <summary>Por pacote</summary>
            <ul className="pack-progress">
              {meta.packs.map((item) => (
                <li key={item.id}>
                  <span>{packNames.get(item.id)}</span> <span>{progressText(item)}</span>
                </li>
              ))}
            </ul>
          </details>
        </section>
      )}

      <CatalogFilters
        title="Filtros da coleção"
        filters={filters}
        onChange={(change) => {
          setFilters((old) => ({ ...old, ...change }));
          setShown(PAGE);
        }}
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
          <section className="card-detail" aria-labelledby="detail-title">
            {detail.data ? (
              <Detail card={detail.data} language={language} packs={packNames} />
            ) : (
              <h2 id="detail-title">Carregando a carta…</h2>
            )}
          </section>
        )}
        <section className="results" aria-label="Cartas da coleção">
          <p role="status">
            {collection.data && catalog.data
              ? `${results.length} ${results.length === 1 ? "carta" : "cartas"}`
              : "Carregando a coleção…"}
          </p>
          <ul className="card-grid">
            {results.slice(0, shown).map((card) => (
              <li key={card.id}>
                <CardTile
                  card={card}
                  language={language}
                  selected={selected === card.id}
                  onSelect={() => setSelected(card.id)}
                >
                  <span className="badge">
                    {owned.get(card.id)} {owned.get(card.id) === 1 ? "cópia" : "cópias"}
                  </span>
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
