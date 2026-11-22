import type { ReactNode } from "react";
import { CardImage } from "./CardImage.tsx";
import {
  IMAGE_WIDTHS,
  cardText,
  displayName,
  frame,
  typeLine,
  type CardDetail,
  type CardSummary,
  type Language,
} from "./cards.ts";
import { ATTRIBUTES, BANLIST, RARITIES, label } from "./labels.ts";

// Peças da tela de cartas, usadas no catálogo, na coleção e no Deck Edit.

// Atributo (com a bolinha da cor dele), nível e ATK/DEF. É um span: aparece também dentro
// do botão da lista, onde parágrafo não pode entrar.
export function Stats({ card }: { card: CardSummary }) {
  if (card.card_type !== "Monster") return null;
  return (
    <span className="stats">
      <span className={`attribute attribute-${card.attribute?.toLowerCase()}`}>
        {label(ATTRIBUTES, card.attribute)}
      </span>
      <span>★ {card.level}</span>
      <span>
        ATK {card.atk ?? "?"} / DEF {card.def ?? "?"}
      </span>
    </span>
  );
}

// Miniatura da lista (o nome está do lado, então a imagem não tem texto alternativo).
export function Thumb({ card }: { card: CardSummary }) {
  return (
    <span className="thumb">
      <CardImage card={card} size="p" width={56} height={82} lazy />
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

export function Field({ id, title, value, onChange, options, all = "Todos" }: FieldProps) {
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

export function Choices(props: {
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

export function Detail({
  card,
  pending,
  language,
  packs,
  onLanguage,
}: {
  card: CardDetail;
  pending?: "loading" | "failed"; // o detalhe ainda não chegou (ou falhou): só falta o texto
  language: Language;
  packs: Map<number, string>;
  onLanguage?: (language: Language) => void; // a troca de idioma fica junto do texto (ADR 0015)
}) {
  const other = language === "pt" ? card.name : card.name_pt;
  const { text, note } = pending
    ? { text: pending === "failed" ? "Não deu para carregar o texto." : "Carregando o texto…" }
    : cardText(card, language);
  return (
    <article className={`detail frame-${frame(card)}`}>
      <h2 id="detail-title">{displayName(card, language)}</h2>
      {other && other !== displayName(card, language) && <p className="other-name">{other}</p>}
      {/* A imagem que a grade já baixou aparece na hora por baixo; a do tamanho da tela (maior
          na tela de alta densidade) cobre por cima quando chega (GXP-107). Sem imagem, fica a
          face da carta. */}
      <div key={card.id} className="detail-image-box">
        <CardImage
          card={card}
          size="m"
          width={IMAGE_WIDTHS.m}
          height={391}
          className="detail-image-thumb"
          alt={card.image === undefined ? `Carta ${displayName(card, language)}, sem imagem` : ""}
        />
        <CardImage
          card={card}
          size="m"
          width={IMAGE_WIDTHS.m}
          height={391}
          className="detail-image"
          alt={`Imagem da carta ${displayName(card, language)}`}
          zoom
          ifMissing="nothing"
        />
      </div>
      <p className="type-line">{typeLine(card)}</p>
      <Stats card={card} />
      {card.banlist && <p className="badge">{label(BANLIST, card.banlist)}</p>}
      <p className="text">{text}</p>
      {note && <p className="muted">{note}</p>}
      {onLanguage && (
        <Choices
          name="language"
          title="Texto das cartas"
          value={language}
          options={{ pt: "Português", en: "Inglês" }}
          onChange={(value) => onLanguage(value as Language)}
        />
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
      {card.source && (
        <p className="muted">
          Dados da <a href={card.source}>Yugipedia</a> (CC BY-SA).
        </p>
      )}
    </article>
  );
}

// Um item da lista. Em grade (o padrão: catálogo e coleção), a carta grande com o nome
// embaixo e as marcas (banlist, raridade, cópias) por cima da imagem; o nome vem primeiro
// no código, para o leitor de tela começar por ele. Em linha (o baú do Deck Edit, até o
// GXP-132), a miniatura com o nome, o tipo e os números ao lado. children traz o que a tela
// quiser a mais; missing apaga a carta que o jogador não tem.
export function CardTile({
  card,
  language,
  selected,
  onSelect,
  children,
  layout = "grid",
  missing = false,
}: {
  card: CardSummary;
  language: Language;
  selected: boolean;
  onSelect: () => void;
  children?: ReactNode;
  layout?: "grid" | "row";
  missing?: boolean;
}) {
  const ban = card.banlist && <span className="badge">{label(BANLIST, card.banlist)}</span>;
  if (layout === "row") {
    return (
      <button
        type="button"
        className={`card-tile row frame-${frame(card)}`}
        aria-current={selected || undefined}
        onClick={onSelect}
      >
        <Thumb card={card} />
        <span className="tile-text">
          <strong>{displayName(card, language)}</strong>
          <span className="type-line">{typeLine(card)}</span>
          <Stats card={card} />
          {ban}
          {children}
        </span>
      </button>
    );
  }
  return (
    <button
      type="button"
      className={`card-tile frame-${frame(card)}${missing ? " missing" : ""}`}
      aria-current={selected || undefined}
      onClick={onSelect}
    >
      <span className="tile-name">{displayName(card, language)}</span>
      <span className="tile-art">
        <CardImage card={card} size="m" width={IMAGE_WIDTHS.m} height={391} lazy />
        {(ban || children) && (
          <span className="tile-marks">
            {ban}
            {children}
          </span>
        )}
      </span>
    </button>
  );
}
