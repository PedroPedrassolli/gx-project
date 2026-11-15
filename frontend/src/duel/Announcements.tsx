import { useState } from "react";
import { displayName } from "../catalog/cards.ts";
import { announceOptions, freeZones, searchCards } from "./announce.ts";
import { cardLabel, Choice, list, type PromptCard, type PromptProps } from "./promptParts.tsx";

// Os anúncios da engine: zona, marcadores, tipo, atributo, nome de carta, número e pedra,
// papel e tesoura. Quando é uma escolha só, o toque já responde.

// Zona para escolher (select_disfield): a resposta é jogador, local e sequência de cada uma.
export function ZoneChoice(props: PromptProps) {
  const { prompt, onAnswer } = props;
  const zones = freeZones(prompt);
  const count = Number(prompt.count);
  const [chosen, setChosen] = useState<number[]>([]);
  const send = (indexes: number[]) =>
    onAnswer({
      places: indexes.flatMap((index) => {
        const zone = zones[index];
        return zone ? [zone.player, zone.location, zone.sequence] : [];
      }),
    });

  if (count === 1) {
    return (
      <p className="actions">
        {zones.map((zone, index) => (
          <Choice key={index} label={zone.label} onClick={() => send([index])} />
        ))}
      </p>
    );
  }
  const toggle = (index: number) =>
    setChosen((current) =>
      current.includes(index) ? current.filter((item) => item !== index) : [...current, index],
    );
  return (
    <>
      <ul className="picks">
        {zones.map((zone, index) => (
          <li key={index}>
            <label>
              <input
                type="checkbox"
                checked={chosen.includes(index)}
                onChange={() => toggle(index)}
              />
              {zone.label}
            </label>
          </li>
        ))}
      </ul>
      <p className="pick-count" aria-live="polite">
        Zonas: {chosen.length} de {count}
      </p>
      <p className="actions">
        <Choice label="Confirmar" disabled={chosen.length !== count} onClick={() => send(chosen)} />
      </p>
    </>
  );
}

// Marcadores para tirar (select_counter): quantos de cada carta, somando o total pedido.
export function CounterChoice(props: PromptProps) {
  const { prompt, onAnswer } = props;
  const cards = list(prompt, "cards") as (PromptCard & { counters: number })[];
  const count = Number(prompt.count);
  const [counts, setCounts] = useState(() => cards.map(() => 0));
  const total = counts.reduce((sum, value) => sum + value, 0);
  const update = (index: number, value: number, max: number) =>
    setCounts((current) =>
      current.map((old, item) =>
        item === index ? Math.min(max, Math.max(0, Number.isNaN(value) ? 0 : value)) : old,
      ),
    );
  return (
    <>
      <ul className="picks">
        {cards.map((card, index) => (
          <li key={index}>
            <label>
              {cardLabel(card, props)}, com {card.counters}
              <input
                type="number"
                className="counter-input"
                min={0}
                max={card.counters}
                value={counts[index]}
                onChange={(event) => update(index, event.target.valueAsNumber, card.counters)}
              />
            </label>
          </li>
        ))}
      </ul>
      <p className="pick-count" aria-live="polite">
        Marcadores: {total} de {count}
      </p>
      <p className="actions">
        <Choice label="Confirmar" disabled={total !== count} onClick={() => onAnswer({ counts })} />
      </p>
    </>
  );
}

// Número da lista da engine (announce_number): a resposta é o índice.
export function NumberChoice(props: PromptProps) {
  const options = (props.prompt.options as number[] | undefined) ?? [];
  return (
    <p className="actions">
      {options.map((value, index) => (
        <Choice key={index} label={String(value)} onClick={() => props.onAnswer({ index })} />
      ))}
    </p>
  );
}

// Pedra, papel e tesoura: 1 é tesoura, 2 pedra e 3 papel (como a engine compara).
const HANDS: [number, string][] = [
  [2, "Pedra"],
  [3, "Papel"],
  [1, "Tesoura"],
];

export function HandChoice(props: PromptProps) {
  return (
    <p className="actions">
      {HANDS.map(([hand, label]) => (
        <Choice key={hand} label={label} onClick={() => props.onAnswer({ hand })} />
      ))}
    </p>
  );
}

// Tipo ou atributo para declarar (announce_race, announce_attrib): a resposta é a máscara
// com os bits escolhidos, exatamente "count" deles.
export function BitsChoice(props: PromptProps) {
  const { prompt, onAnswer } = props;
  const options = announceOptions(prompt);
  const count = Number(prompt.count);
  const [mask, setMask] = useState(0);
  if (count === 1) {
    return (
      <p className="actions">
        {options.map(({ bit, label }) => (
          <Choice key={bit} label={label} onClick={() => onAnswer({ mask: bit })} />
        ))}
      </p>
    );
  }
  const chosen = options.filter(({ bit }) => (mask & bit) !== 0).length;
  return (
    <>
      <ul className="picks">
        {options.map(({ bit, label }) => (
          <li key={bit}>
            <label>
              <input
                type="checkbox"
                checked={(mask & bit) !== 0}
                onChange={() => setMask((current) => current ^ bit)}
              />
              {label}
            </label>
          </li>
        ))}
      </ul>
      <p className="pick-count" aria-live="polite">
        Escolhidos: {chosen} de {count}
      </p>
      <p className="actions">
        <Choice label="Confirmar" disabled={chosen !== count} onClick={() => onAnswer({ mask })} />
      </p>
    </>
  );
}

// Nome de carta para declarar (announce_card): busca no catálogo e manda o código. Quem
// confere se a carta vale (os opcodes da pergunta) é a engine.
export function CardNameChoice(props: PromptProps) {
  const [query, setQuery] = useState("");
  const found = searchCards(props.cards.values(), query, props.language);
  return (
    <>
      <p>
        <label>
          Nome da carta{" "}
          <input type="search" value={query} onChange={(event) => setQuery(event.target.value)} />
        </label>
      </p>
      <p className="actions">
        {found.map((card) => (
          <Choice
            key={card.id}
            label={displayName(card, props.language)}
            onClick={() => props.onAnswer({ code: card.code })}
          />
        ))}
      </p>
      {query.trim().length >= 2 && found.length === 0 && (
        <p className="pick-count">Nenhuma carta com esse nome.</p>
      )}
    </>
  );
}
