import type { ReactNode } from "react";
import type { Prompt } from "./api.ts";
import { CardChoice, SortChoice, UnselectChoice } from "./CardChoice.tsx";
import { hintText } from "./hints.ts";
import { cardLabel, Choice, list, type PromptCard, type PromptProps } from "./promptParts.tsx";

// As perguntas da engine para o jogador (escopo 4, "Prompts do duelo"): cada tipo vira um
// formulário com botões, que manda a escolha em JSON (o servidor monta os bytes).
type Props = PromptProps;

const IDLE: [string, string, string][] = [
  ["summonable", "summon", "Invocar"],
  ["spsummonable", "spsummon", "Invocar por Invocação-Especial"],
  ["repositionable", "reposition", "Mudar a posição de"],
  ["msetable", "mset", "Baixar"],
  ["ssetable", "sset", "Baixar"],
  ["activatable", "activate", "Ativar"],
];

const BATTLE: [string, string, string][] = [
  ["attackable", "attack", "Atacar com"],
  ["activatable", "activate", "Ativar"],
];

const POSITIONS: [number, string][] = [
  [0x1, "Ataque, com a face para cima"],
  [0x2, "Ataque, com a face para baixo"],
  [0x4, "Defesa, com a face para cima"],
  [0x8, "Defesa, com a face para baixo"],
];

export function PromptPanel(props: Props) {
  const { prompt } = props;
  return (
    <section className="prompt-panel" aria-labelledby="prompt-title">
      <h2 id="prompt-title">{title(prompt, props)}</h2>
      <fieldset disabled={props.pending}>
        <legend className="visually-hidden">Escolha</legend>
        {body(props)}
      </fieldset>
    </section>
  );
}

function title(prompt: Prompt, props: Props) {
  switch (prompt.type) {
    case "select_idlecmd":
      return "Fase principal: o que fazer?";
    case "select_battlecmd":
      return "Batalha: o que fazer?";
    case "select_chain":
      return "Encadear?";
    case "select_effectyn":
      return (
        (prompt.text as string) ??
        `Ativar o efeito de ${cardLabel(prompt as unknown as PromptCard, props)}?`
      );
    case "select_yesno":
      return (prompt.text as string) ?? "Confirmar?";
    case "select_option":
      return "Escolha uma opção";
    case "select_position":
      return hintText(prompt) ?? "Em que posição?";
    case "select_card":
    case "select_tribute":
    case "select_sum":
    case "select_unselect_card":
      return hintText(prompt) ?? "Escolha as cartas";
    case "sort_card":
      return hintText(prompt) ?? "Ordene as cartas";
    case "sort_chain":
      return "Ordem dos efeitos na corrente";
    default:
      return hintText(prompt) ?? "Sua vez";
  }
}

function body(props: Props): ReactNode {
  const { prompt, onAnswer } = props;
  switch (prompt.type) {
    case "select_idlecmd":
      return (
        <>
          <Commands {...props} groups={IDLE} />
          <p className="actions">
            {Boolean(prompt.to_bp) && (
              <Choice label="Ir para a Batalha" onClick={() => onAnswer({ command: "battle" })} />
            )}
            {Boolean(prompt.to_ep) && (
              <Choice label="Encerrar o turno" onClick={() => onAnswer({ command: "end" })} />
            )}
          </p>
        </>
      );
    case "select_battlecmd":
      return (
        <>
          <Commands {...props} groups={BATTLE} />
          <p className="actions">
            {Boolean(prompt.to_m2) && (
              <Choice
                label="Ir para a Principal 2"
                onClick={() => onAnswer({ command: "main2" })}
              />
            )}
            {Boolean(prompt.to_ep) && (
              <Choice label="Encerrar o turno" onClick={() => onAnswer({ command: "end" })} />
            )}
          </p>
        </>
      );
    case "select_chain":
      return (
        <p className="actions">
          {list(prompt, "chains").map((card, index) => (
            <Choice
              key={index}
              label={`Encadear ${cardLabel(card, props)}`}
              detail={card.text}
              onClick={() => onAnswer({ index })}
            />
          ))}
          {!prompt.forced && (
            <Choice label="Não encadear" onClick={() => onAnswer({ index: -1 })} />
          )}
        </p>
      );
    case "select_effectyn":
    case "select_yesno":
      return (
        <p className="actions">
          <Choice label="Sim" onClick={() => onAnswer({ yes: true })} />
          <Choice label="Não" onClick={() => onAnswer({ yes: false })} />
        </p>
      );
    case "select_option": {
      const texts = (prompt.options_text as (string | null)[] | undefined) ?? [];
      return (
        <p className="actions">
          {((prompt.options as number[] | undefined) ?? []).map((_, index) => (
            <Choice
              key={index}
              label={texts[index] ?? `Opção ${index + 1}`}
              onClick={() => onAnswer({ index })}
            />
          ))}
        </p>
      );
    }
    case "select_position":
      return (
        <p className="actions">
          {POSITIONS.filter(([bit]) => (Number(prompt.positions) & bit) !== 0).map(
            ([position, label]) => (
              <Choice key={position} label={label} onClick={() => onAnswer({ position })} />
            ),
          )}
        </p>
      );
    case "select_card":
    case "select_tribute":
    case "select_sum":
      return <CardChoice {...props} />;
    case "select_unselect_card":
      return <UnselectChoice {...props} />;
    case "sort_card":
    case "sort_chain":
      return <SortChoice {...props} />;
    default:
      return <p>Esta pergunta ainda não tem tela.</p>;
  }
}

// Ações sobre cartas (invocar, ativar, atacar...), uma lista por tipo de ação.
function Commands(props: Props & { groups: [string, string, string][] }) {
  return (
    <>
      {props.groups.map(([key, command, verb]) => {
        const items = list(props.prompt, key);
        if (items.length === 0) return null;
        return (
          <p key={key} className="actions">
            {items.map((card, index) => (
              <Choice
                key={index}
                label={`${verb} ${cardLabel(card, props)}`}
                detail={card.text}
                onClick={() => props.onAnswer({ command, index })}
              />
            ))}
          </p>
        );
      })}
    </>
  );
}
