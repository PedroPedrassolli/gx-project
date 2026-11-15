import { useState } from "react";
import { canConfirm, progress, sortOrder } from "./choices.ts";
import {
  cardLabel,
  CardThumb,
  Choice,
  list,
  type PromptCard,
  type PromptProps,
} from "./promptParts.tsx";

// Escolha de cartas (select_card, select_tribute, select_sum). Tocar marca a carta e mostra
// o detalhe dela (GXP-79); o "Confirmar" é que responde, e só libera o que a engine aceita.
// Antes, numa carta só, o toque já respondia, e não dava para ver o que cada uma fazia.
export function CardChoice(props: PromptProps) {
  const { prompt, onAnswer } = props;
  const cards = list(prompt, "cards");
  const [chosen, setChosen] = useState<number[]>([]);
  const single = prompt.type !== "select_sum" && Number(prompt.max) === 1;
  const cancel = Boolean(prompt.cancelable) && (
    <Choice label="Cancelar" onClick={() => onAnswer({ cancel: true })} />
  );

  // Numa carta só, marcar troca a escolha; em várias, liga e desliga.
  const pick = (index: number) => {
    const marking = !chosen.includes(index);
    setChosen((current) =>
      single ? [index] : marking ? [...current, index] : current.filter((item) => item !== index),
    );
    if (marking) show(props, cards[index]);
  };
  const must = list(prompt, "must");
  return (
    <>
      {must.length > 0 && (
        <p>Já entram: {must.map((card) => cardLabel(card, props)).join(", ")}.</p>
      )}
      <PickList
        {...props}
        items={cards}
        chosen={chosen}
        type={single ? "radio" : "checkbox"}
        onPick={pick}
      />
      {!single && (
        <p className="pick-count" aria-live="polite">
          {progress(prompt, chosen)}
        </p>
      )}
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

// Uma carta por resposta (select_unselect_card): marca uma das que entram ou das que saem e
// confirma; a engine pergunta de novo com as listas novas. O -1 conclui quando a escolha já
// vale e desiste quando ainda não vale.
export function UnselectChoice(props: PromptProps) {
  const { prompt, onAnswer } = props;
  const selectable = list(prompt, "selectable");
  const unselectable = list(prompt, "unselectable");
  // Os índices da resposta: primeiro as que entram, depois as que saem.
  const cards = [...selectable, ...unselectable];
  const [chosen, setChosen] = useState<number | null>(null);
  const pick = (index: number) => {
    setChosen(index);
    show(props, cards[index]);
  };
  return (
    <>
      {selectable.length > 0 && (
        <PickList
          {...props}
          items={selectable}
          chosen={chosen === null ? [] : [chosen]}
          type="radio"
          onPick={pick}
        />
      )}
      {unselectable.length > 0 && (
        <>
          <p>Já escolhidas (marque para tirar):</p>
          <PickList
            {...props}
            items={unselectable}
            offset={selectable.length}
            chosen={chosen === null ? [] : [chosen]}
            type="radio"
            onPick={pick}
          />
        </>
      )}
      <p className="actions">
        <Choice
          label={chosen !== null && chosen >= selectable.length ? "Tirar" : "Confirmar"}
          disabled={chosen === null}
          onClick={() => onAnswer({ index: chosen })}
        />
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

// A lista para marcar, com a miniatura de cada carta. "offset" soma ao índice quando a lista
// é a segunda parte das respostas (as que saem, no select_unselect_card).
function PickList(
  props: PromptProps & {
    items: PromptCard[];
    chosen: number[];
    type: "radio" | "checkbox";
    offset?: number;
    onPick: (index: number) => void;
  },
) {
  const offset = props.offset ?? 0;
  return (
    <ul className="picks">
      {props.items.map((card, position) => {
        const index = offset + position;
        return (
          <li key={index}>
            <label>
              <input
                type={props.type}
                name="pick"
                checked={props.chosen.includes(index)}
                onChange={() => props.onPick(index)}
              />
              <CardThumb card={card} cards={props.cards} />
              {cardLabel(card, props)}
            </label>
          </li>
        );
      })}
    </ul>
  );
}

// O detalhe só existe para a carta que o jogador vê e que está no catálogo.
function show(props: PromptProps, card: PromptCard | undefined) {
  if (card && card.code !== 0 && props.cards.has(card.code)) props.onCard?.(card.code);
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
