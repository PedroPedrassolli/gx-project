import type { ReactNode, SyntheticEvent } from "react";
import {
  IMAGE_WIDTHS,
  displayName,
  frame,
  imageUrl,
  typeLine,
  type CardDetail,
  type CardSummary,
  type Language,
} from "./cards.ts";
import { ATTRIBUTES, BANLIST, RARITIES, label } from "./labels.ts";

// Peças da tela de cartas, usadas no catálogo, na coleção e no Deck Edit.

export function Stats({ card }: { card: CardSummary }) {
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
export function Thumb({ card }: { card: CardSummary }) {
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

// Um item da lista: miniatura, nome, tipo, ATK/DEF e a banlist. children traz o que a
// tela quiser a mais (raridade no pacote, quantas cópias o jogador tem).
export function CardTile({
  card,
  language,
  selected,
  onSelect,
  children,
}: {
  card: CardSummary;
  language: Language;
  selected: boolean;
  onSelect: () => void;
  children?: ReactNode;
}) {
  return (
    <button
      type="button"
      className={`card-tile frame-${frame(card)}`}
      aria-current={selected || undefined}
      onClick={onSelect}
    >
      <Thumb card={card} />
      <span className="tile-text">
        <strong>{displayName(card, language)}</strong>
        <span className="type-line">{typeLine(card)}</span>
        <Stats card={card} />
        {card.banlist && <span className="badge">{label(BANLIST, card.banlist)}</span>}
        {children}
      </span>
    </button>
  );
}
