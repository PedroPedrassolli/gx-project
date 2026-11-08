import { useEffect, useMemo, useRef, useState, type SyntheticEvent } from "react";
import {
  EMPTY_FILTERS,
  IMAGE_WIDTHS,
  displayName,
  frame,
  imageUrl,
  matches,
  sortCards,
  typeLine,
  type CardDetail,
  type CardSummary,
  type Filters,
  type Language,
  type Pack,
} from "./cards.ts";
import {
  ATTRIBUTES,
  BANLIST,
  CARD_TYPES,
  MONSTER_TYPES,
  RACES,
  RARITIES,
  label,
} from "./labels.ts";

const PAGE = 60; // cartas por vez na lista; "Mostrar mais" traz as próximas
const LANGUAGE_KEY = "gx-idioma-das-cartas";
const LEVELS = Object.fromEntries(Array.from({ length: 12 }, (_, i) => [i + 1, String(i + 1)]));
type TextFilter = Exclude<keyof Filters, "sort" | "order">;
const MORE_FILTERS: [TextFilter, string, Record<string, string>?][] = [
  ["attribute", "Atributo", ATTRIBUTES],
  ["race", "Tipo de monstro", RACES],
  ["monsterType", "Categoria", MONSTER_TYPES],
  ["level", "Nível", LEVELS],
  ["atkMin", "ATK mínimo"],
  ["atkMax", "ATK máximo"],
  ["defMin", "DEF mínima"],
  ["defMax", "DEF máxima"],
];
const SORTS: Record<string, string> = {
  "name-asc": "Nome (A a Z)",
  "name-desc": "Nome (Z a A)",
  "atk-desc": "Maior ATK",
  "atk-asc": "Menor ATK",
  "def-desc": "Maior DEF",
  "def-asc": "Menor DEF",
  "level-desc": "Maior nível",
  "level-asc": "Menor nível",
  "type-asc": "Tipo de carta",
};

async function getData<T>(url: string): Promise<T> {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`${url}: ${response.status}`);
  return ((await response.json()) as { data: T }).data;
}

function savedLanguage(): Language {
  try {
    return localStorage.getItem(LANGUAGE_KEY) === "en" ? "en" : "pt";
  } catch {
    return "pt";
  }
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

// Imagem que não carregou some: fica a cor da moldura na lista e só o texto no detalhe.
function hide(event: SyntheticEvent<HTMLImageElement>) {
  event.currentTarget.hidden = true;
}

// Miniatura da lista (o nome está do lado, então a imagem não tem texto alternativo).
function Thumb({ card }: { card: CardSummary }) {
  return (
    <span className="thumb">
      {card.image !== undefined && (
        <img
          src={imageUrl(card.image, "p")}
          alt=""
          width={56}
          height={82}
          loading="lazy"
          decoding="async"
          onError={hide}
        />
      )}
    </span>
  );
}

type FieldProps = {
  id: string;
  title: string;
  value: string;
  onChange: (value: string) => void;
  options?: Record<string, string>; // sem opções, é um campo de número (ATK e DEF)
  all?: string; // primeira opção, que não filtra nada
};

function Field({ id, title, value, onChange, options, all = "Todos" }: FieldProps) {
  return (
    <div className="field">
      <label htmlFor={id}>{title}</label>
      {options ? (
        <select id={id} value={value} onChange={(event) => onChange(event.target.value)}>
          {all && <option value="">{all}</option>}
          {Object.entries(options).map(([key, text]) => (
            <option key={key} value={key}>
              {text}
            </option>
          ))}
        </select>
      ) : (
        <input
          id={id}
          type="number"
          min="0"
          step="100"
          inputMode="numeric"
          value={value}
          onChange={(event) => onChange(event.target.value)}
        />
      )}
    </div>
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

function Detail({
  card,
  language,
  packs,
}: {
  card: CardDetail;
  language: Language;
  packs: Map<number, string>;
}) {
  const other = language === "pt" ? card.name : card.name_pt;
  const text = language === "pt" ? (card.text_pt ?? card.text) : card.text;
  return (
    <article className={`detail frame-${frame(card)}`}>
      <h2 id="detail-title">{displayName(card, language)}</h2>
      {other && other !== displayName(card, language) && <p className="other-name">{other}</p>}
      {card.image !== undefined && (
        <img
          key={card.id}
          className="detail-image"
          src={imageUrl(card.image, "m")}
          srcSet={`${imageUrl(card.image, "m")} ${IMAGE_WIDTHS.m}w, ${imageUrl(card.image, "g")} ${IMAGE_WIDTHS.g}w`}
          sizes={`${IMAGE_WIDTHS.m}px`}
          width={IMAGE_WIDTHS.m}
          height={391}
          alt={`Imagem da carta ${displayName(card, language)}`}
          onError={hide}
        />
      )}
      <p className="type-line">{typeLine(card)}</p>
      <Stats card={card} />
      {card.banlist && <p className="badge">{label(BANLIST, card.banlist)}</p>}
      <p className="text">{text}</p>
      {language === "pt" && !card.text_pt && (
        <p className="muted">Sem texto em português: este é o texto em inglês.</p>
      )}
      {card.name_in_game && <p className="muted">No jogo: {card.name_in_game}</p>}
      {card.packs && (
        <>
          <h3>Pacotes</h3>
          <ul className="packs">
            {card.packs.map((item) => (
              <li key={item.id}>
                {packs.get(item.id)} · {label(RARITIES, item.rarity)}
              </li>
            ))}
          </ul>
        </>
      )}
      <p className="muted">
        Dados da <a href={card.source}>Yugipedia</a> (CC BY-SA).
      </p>
    </article>
  );
}

export function Catalog() {
  const [attempt, setAttempt] = useState(0);
  const [catalog, setCatalog] = useState<{ cards: CardSummary[]; packs: Pack[] } | null>(null);
  const [failed, setFailed] = useState(false);
  const [filters, setFilters] = useState<Filters>(EMPTY_FILTERS);
  const [pack, setPack] = useState("");
  const [packLoaded, setPackLoaded] = useState<{
    pack: string;
    rarities: Map<number, string>;
  } | null>(null);
  const [language, setLanguage] = useState<Language>(savedLanguage);
  const [shown, setShown] = useState(PAGE);
  const [selected, setSelected] = useState(
    () => Number(new URLSearchParams(location.search).get("carta")) || 0,
  );
  const [detail, setDetail] = useState<CardDetail | null>(null);
  const [missing, setMissing] = useState(0); // id da carta que a API não achou
  const panel = useRef<HTMLElement>(null);

  useEffect(() => {
    Promise.all([getData<CardSummary[]>("/api/cards"), getData<Pack[]>("/api/packs")])
      .then(([cards, packs]) => setCatalog({ cards, packs }))
      .catch(() => setFailed(true));
  }, [attempt]);

  useEffect(() => {
    if (pack === "") return;
    let current = true;
    getData<CardSummary[]>(`/api/cards?pack=${pack}`)
      .then(
        (cards) =>
          current &&
          setPackLoaded({
            pack,
            rarities: new Map(cards.map((card) => [card.id, card.rarity ?? ""])),
          }),
      )
      .catch(() => current && setFailed(true));
    return () => {
      current = false;
    };
  }, [pack]);

  useEffect(() => {
    if (!selected) return;
    let current = true;
    getData<CardDetail>(`/api/cards/${selected}`)
      .then((card) => current && setDetail(card))
      .catch(() => current && setMissing(selected));
    return () => {
      current = false;
    };
  }, [selected]);

  const rarities = pack !== "" && packLoaded?.pack === pack ? packLoaded.rarities : null;
  const results = useMemo(() => {
    if (!catalog || (pack !== "" && !rarities)) return [];
    const list = catalog.cards.filter(
      (card) => matches(card, filters) && (!rarities || rarities.has(card.id)),
    );
    return sortCards(list, filters, language);
  }, [catalog, filters, pack, rarities, language]);
  const packNames = useMemo(
    () => new Map(catalog?.packs.map((item) => [item.id, item.name])),
    [catalog],
  );

  function update(change: Partial<Filters>) {
    setFilters((old) => ({ ...old, ...change }));
    setShown(PAGE);
  }

  function chooseLanguage(value: Language) {
    setLanguage(value);
    try {
      localStorage.setItem(LANGUAGE_KEY, value);
    } catch {
      // Sem armazenamento (aba anônima, por exemplo): vale só nesta visita.
    }
  }

  function select(id: number) {
    setSelected(id);
    const url = new URL(location.href);
    url.searchParams.set("carta", String(id));
    history.replaceState(null, "", url);
    if (matchMedia("(max-width: 959px)").matches) panel.current?.scrollIntoView({ block: "start" });
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

  const cardDetail = detail?.id === selected ? detail : null;
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
        <details className="more">
          <summary>Mais filtros</summary>
          <div className="more-fields">
            {MORE_FILTERS.map(([key, title, options]) => (
              <Field
                key={key}
                id={key}
                title={title}
                options={options}
                value={filters[key]}
                onChange={(value) => update({ [key]: value })}
              />
            ))}
            <Field
              id="pack"
              title="Pacote"
              value={pack}
              options={Object.fromEntries(catalog?.packs.map((item) => [item.id, item.name]) ?? [])}
              onChange={(value) => {
                setPack(value);
                setShown(PAGE);
              }}
            />
          </div>
        </details>
        <Field
          id="sort"
          title="Ordenar por"
          value={`${filters.sort}-${filters.order}`}
          options={SORTS}
          all=""
          onChange={(value) => {
            const [sort, order] = value.split("-") as [Filters["sort"], Filters["order"]];
            update({ sort, order });
          }}
        />
        <Choices
          name="language"
          title="Texto das cartas"
          value={language}
          options={{ pt: "Português", en: "Inglês" }}
          onChange={(value) => chooseLanguage(value as Language)}
        />
        <button
          type="button"
          className="reset"
          onClick={() => {
            setFilters(EMPTY_FILTERS);
            setPack("");
            setShown(PAGE);
          }}
        >
          Limpar filtros
        </button>
      </form>

      <div className="catalog-body">
        {selected > 0 && (
          <section className="card-detail" aria-labelledby="detail-title" ref={panel}>
            {cardDetail ? (
              <Detail card={cardDetail} language={language} packs={packNames} />
            ) : (
              <h2 id="detail-title">
                {missing === selected ? "Carta não encontrada." : "Carregando a carta…"}
              </h2>
            )}
          </section>
        )}
        <section className="results" aria-label="Cartas">
          <p role="status">
            {catalog
              ? `${results.length} ${results.length === 1 ? "carta" : "cartas"}`
              : "Carregando as cartas…"}
          </p>
          <ul className="card-grid">
            {results.slice(0, shown).map((card) => (
              <li key={card.id}>
                <button
                  type="button"
                  className={`card-tile frame-${frame(card)}`}
                  aria-current={selected === card.id || undefined}
                  onClick={() => select(card.id)}
                >
                  <Thumb card={card} />
                  <span className="tile-text">
                    <strong>{displayName(card, language)}</strong>
                    <span className="type-line">{typeLine(card)}</span>
                    <Stats card={card} />
                    {card.banlist && <span className="badge">{label(BANLIST, card.banlist)}</span>}
                    {rarities && (
                      <span className="badge">{label(RARITIES, rarities.get(card.id))}</span>
                    )}
                  </span>
                </button>
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
