import type { ReactNode } from "react";
import type { Filters, Language, Pack } from "./cards.ts";
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
  language: Language;
  onLanguage: (language: Language) => void;
  onReset: () => void;
  children?: ReactNode; // filtros a mais da tela (coleção e Deck Edit)
};

// Os filtros do escopo 3.3: nome, tipo de carta e, em "Mais filtros", o resto.
export function CatalogFilters(props: Props) {
  const { filters, onChange } = props;
  return (
    <form
      className="filters"
      role="search"
      aria-label={props.title}
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
          onChange={(event) => onChange({ q: event.target.value })}
        />
      </div>
      <Choices
        name="card-type"
        title="Tipo de carta"
        value={filters.cardType}
        options={{ "": "Todas", ...CARD_TYPES }}
        onChange={(value) => onChange({ cardType: value })}
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
          {props.children}
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
          onChange({ sort, order });
        }}
      />
      <Choices
        name="language"
        title="Texto das cartas"
        value={props.language}
        options={{ pt: "Português", en: "Inglês" }}
        onChange={(value) => props.onLanguage(value as Language)}
      />
      <button type="button" className="reset" onClick={props.onReset}>
        Limpar filtros
      </button>
    </form>
  );
}
