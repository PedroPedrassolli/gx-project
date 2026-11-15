import { useState } from "react";
import { canConfirm, progress } from "./choices.ts";
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
