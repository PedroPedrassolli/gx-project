import { useState } from "react";
import { canConfirm, progress, sortOrder } from "./choices.ts";
import { cardLabel, Choice, list, type PromptProps } from "./promptParts.tsx";

// Escolha de cartas (select_card, select_tribute, select_sum). Quando é uma carta só, o
// toque já responde; com mais, as caixas e o "Confirmar", que só libera o que a engine aceita.
export function CardChoice(props: PromptProps) {
  const { prompt, onAnswer } = props;
  const cards = list(prompt, "cards");
  const [chosen, setChosen] = useState<number[]>([]);
  const cancel = Boolean(prompt.cancelable) && (
    <Choice label="Cancelar" onClick={() => onAnswer({ cancel: true })} />
  );

  if (prompt.type !== "select_sum" && Number(prompt.max) === 1) {
    return (
      <p className="actions">
        {cards.map((card, index) => (
          <Choice
            key={index}
            label={cardLabel(card, props)}
            onClick={() => onAnswer({ indexes: [index] })}
          />
        ))}
        {cancel}
      </p>
    );
  }

  const toggle = (index: number) =>
    setChosen((current) =>
      current.includes(index) ? current.filter((item) => item !== index) : [...current, index],
    );
  const must = list(prompt, "must");
  return (
    <>
      {must.length > 0 && (
        <p>Já entram: {must.map((card) => cardLabel(card, props)).join(", ")}.</p>
      )}
      <ul className="picks">
        {cards.map((card, index) => (
          <li key={index}>
            <label>
              <input
                type="checkbox"
                checked={chosen.includes(index)}
                onChange={() => toggle(index)}
              />
              {cardLabel(card, props)}
            </label>
          </li>
        ))}
      </ul>
      <p className="pick-count" aria-live="polite">
        {progress(prompt, chosen)}
      </p>
      <p className="actions">
        <Choice
          label="Confirmar"
          disabled={!canConfirm(prompt, chosen)}
          onClick={() => onAnswer({ indexes: chosen })}
        />
        {cancel}
      </p>
    </>
  );
}

// Uma carta por resposta (select_unselect_card): a engine pergunta de novo com as listas
// novas. O -1 conclui quando a escolha já vale e desiste quando ainda não vale.
export function UnselectChoice(props: PromptProps) {
  const { prompt, onAnswer } = props;
  const selectable = list(prompt, "selectable");
  const unselectable = list(prompt, "unselectable");
  return (
    <>
      <p className="actions">
        {selectable.map((card, index) => (
          <Choice
            key={index}
            label={`Escolher ${cardLabel(card, props)}`}
            onClick={() => onAnswer({ index })}
          />
        ))}
      </p>
      {unselectable.length > 0 && (
        <p className="actions">
          {unselectable.map((card, index) => (
            <Choice
              key={index}
              label={`Tirar ${cardLabel(card, props)}`}
              onClick={() => onAnswer({ index: selectable.length + index })}
            />
          ))}
        </p>
      )}
      <p className="actions">
        {prompt.finishable ? (
          <Choice label="Concluir" onClick={() => onAnswer({ index: -1 })} />
        ) : (
          Boolean(prompt.cancelable) && (
            <Choice label="Cancelar" onClick={() => onAnswer({ index: -1 })} />
          )
        )}
      </p>
    </>
  );
}

// Ordem de cartas (sort_card) ou de efeitos na corrente (sort_chain): toque na ordem.
export function SortChoice(props: PromptProps) {
  const { prompt, onAnswer } = props;
  const cards = list(prompt, "cards");
  const [taps, setTaps] = useState<number[]>([]);
  return (
    <>
      <p>
        {prompt.type === "sort_chain"
          ? "Toque nos efeitos na ordem em que entram na corrente."
          : "Toque nas cartas na ordem: a primeira fica em cima."}
      </p>
      <p className="actions">
        {cards.map((card, index) => {
          const position = taps.indexOf(index);
          return (
            <Choice
              key={index}
              label={`${position >= 0 ? `${position + 1}º: ` : ""}${cardLabel(card, props)}`}
              disabled={position >= 0}
              onClick={() => setTaps([...taps, index])}
            />
          );
        })}
      </p>
      <p className="actions">
        <Choice
          label="Confirmar"
          disabled={taps.length < cards.length}
          onClick={() => onAnswer({ order: sortOrder(taps, cards.length) })}
        />
        {taps.length > 0 && <Choice label="Recomeçar" onClick={() => setTaps([])} />}
        <Choice label="Deixar como está" onClick={() => onAnswer({})} />
      </p>
    </>
  );
}
