import { useId, useRef, type ReactNode } from "react";
import type { Filters, Pack } from "./cards.ts";
import { ATTRIBUTES, CARD_TYPES, MONSTER_TYPES, RACES } from "./labels.ts";
import { Choices, Field } from "./parts.tsx";

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

type Props = {
  title: string; // nome do formulário para o leitor de tela ("Filtros do catálogo")
  filters: Filters;
  onChange: (change: Partial<Filters>) => void;
  pack: string;
  onPack: (pack: string) => void;
  packs: Pack[];
  onReset: () => void;
  canReset: boolean; // algum filtro mudou: sem isso, não há o que limpar
  results?: number; // quantas cartas passam: o botão da gaveta diz quantas vai mostrar
  children?: ReactNode; // filtros a mais da tela (coleção e Deck Edit)
};

// Quantos filtros da gaveta estão ligados (o número aparece no botão "Filtros").
function moreCount(filters: Filters, pack: string) {
  return MORE_FILTERS.filter(([key]) => filters[key] !== "").length + (pack === "" ? 0 : 1);
}

// Os filtros do escopo 3.3 (ADR 0015): a busca pelo nome e o tipo de carta sempre à vista; o
// resto (atributo, nível, ATK, pacote, ordem e os da tela) numa gaveta, que no celular sobe
// de baixo. O <dialog> nativo cuida do foco, do Esc e do fundo.
export function CatalogFilters(props: Props) {
  const { filters, onChange } = props;
  const sheet = useRef<HTMLDialogElement>(null);
  const sheetTitle = useId();
  const count = moreCount(filters, props.pack);
  return (
    <form
      className="filters"
      role="search"
      aria-label={props.title}
      onSubmit={(event) => event.preventDefault()}
    >
      <div className="filter-bar">
        <div className="search-field">
          <label htmlFor="q" className="visually-hidden">
            Nome
          </label>
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <circle cx="11" cy="11" r="7" />
            <path d="m20 20-3.5-3.5" />
          </svg>
          <input
            id="q"
            type="search"
            placeholder="Buscar pelo nome"
            enterKeyHint="search"
            autoCorrect="off"
            autoCapitalize="off"
            spellCheck={false}
            value={filters.q}
            onChange={(event) => onChange({ q: event.target.value })}
          />
        </div>
        <button
          type="button"
          className="filter-button"
          aria-haspopup="dialog"
          onClick={() => sheet.current?.showModal()}
        >
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M3 5h18l-7 8v6l-4 2v-8z" />
          </svg>
          Filtros
          {count > 0 && <span className="filter-count">{count}</span>}
        </button>
      </div>
      <div className="filter-chips">
        <Choices
          name="card-type"
          title="Tipo de carta"
          value={filters.cardType}
          options={{ "": "Todas", ...CARD_TYPES }}
          onChange={(value) => onChange({ cardType: value })}
        />
        <button
          type="button"
          className="reset link-button"
          disabled={!props.canReset}
          onClick={props.onReset}
        >
          Limpar filtros
        </button>
      </div>
      <dialog ref={sheet} className="filter-sheet" closedby="any" aria-labelledby={sheetTitle}>
        <h2 id={sheetTitle}>Filtros</h2>
        <div className="more-fields">
          {MORE_FILTERS.map(([key, title, options]) => (
            <Field
              key={key}
              id={key}
              title={title}
              options={options}
              value={filters[key]}
              onChange={(value) => onChange({ [key]: value })}
            />
          ))}
          <Field
            id="pack"
            title="Pacote"
            value={props.pack}
            options={Object.fromEntries(props.packs.map((item) => [item.id, item.name]))}
            onChange={props.onPack}
          />
          <Field
            id="sort"
            title="Ordenar por"
            value={`${filters.sort}-${filters.order}`}
            options={SORTS}
            all=""
            onChange={(value) => {
              const [sort, order] = value.split("-") as [Filters["sort"], Filters["order"]];
              onChange({ sort, order });
            }}
          />
          {props.children}
        </div>
        <p className="actions">
          <button type="button" className="cta" onClick={() => sheet.current?.close()}>
            {props.results === undefined
              ? "Ver as cartas"
              : `Ver ${props.results} ${props.results === 1 ? "carta" : "cartas"}`}
          </button>
        </p>
      </dialog>
    </form>
  );
}
