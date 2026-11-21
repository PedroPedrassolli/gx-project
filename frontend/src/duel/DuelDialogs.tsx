import { useEffect, useRef, useState, type ReactNode } from "react";
import { displayName, imageUrl, type CardSummary, type Language } from "../catalog/cards.ts";
import { useCardDetail } from "../catalog/data.ts";
import { Stats } from "../catalog/parts.tsx";
import type { ChainLink, Prompt } from "./api.ts";
import type { Command } from "./commands.ts";
import { ChainStack } from "./DuelSide.tsx";
import { PromptBody, promptTitle } from "./PromptPanel.tsx";
import type { Answer } from "./promptParts.tsx";

// Os modais do duelo (GXP-99): a pergunta da engine, as ações da carta tocada e a lista de
// todas as ações. O <dialog> nativo cuida do foco, do Esc, do botão voltar do celular e do
// fundo; ao fechar, o foco volta sozinho para quem abriu.

type Base = {
  you: number;
  cards: Map<number, CardSummary>;
  language: Language;
  pending: boolean;
  error?: string;
  onAnswer: Answer;
  onCard: (code: number) => void;
};

// Abre o modal quando "open" fica verdadeiro e fecha quando fica falso.
function useModal(open: boolean) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const element = dialog.current;
    if (!element) return;
    if (open && !element.open) element.showModal();
    if (!open && element.open) element.close();
  }, [open]);
  return dialog;
}

// O texto da carta dentro do modal: a escolhida na lista ou a tocada na mesa. Fica no próprio
// modal, para o jogador ler e continuar escolhendo sem fechar nada.
function CardText(props: {
  code: number | null;
  cards: Map<number, CardSummary>;
  language: Language;
}) {
  const summary = props.code ? props.cards.get(props.code) : undefined;
  const detail = useCardDetail(summary?.id ?? 0);
  if (!summary) return null;
  const card = detail.data;
  const text = card && (props.language === "pt" ? (card.text_pt ?? card.text) : card.text);
  return (
    <section className="card-text" aria-labelledby="card-text-title" aria-live="polite">
      <h3 id="card-text-title">{displayName(summary, props.language)}</h3>
      <Stats card={summary} />
      <p>{text ?? (detail.isError ? "Não deu para carregar o texto." : "Carregando o texto…")}</p>
    </section>
  );
}

function ErrorLine({ error }: { error?: string }) {
  if (!error) return null;
  return (
    <p role="alert" className="form-error">
      {error}
    </p>
  );
}

// A pergunta da vez (corrente, sim ou não, posição, escolher cartas...). "Ver a mesa" e o Esc
// minimizam: o modal fecha e a faixa das fases mostra "Responder" para abrir de novo.
export function PromptDialog(
  props: Base & {
    prompt: Prompt;
    chain: ChainLink[];
    names: string[];
    minimized: boolean;
    onMinimize: () => void;
  },
) {
  const dialog = useModal(!props.minimized);
  const title = promptTitle(props.prompt, props);
  // A carta marcada na lista mostra o texto aqui embaixo (GXP-79), sem sair do modal.
  const [preview, setPreview] = useState<number | null>(null);
  return (
    <dialog
      ref={dialog}
      className="duel-dialog prompt-dialog"
      aria-labelledby="prompt-title"
      onClose={props.onMinimize}
    >
      <header className="duel-dialog-header">
        <h2 id="prompt-title">{title}</h2>
        <button type="button" className="secondary" onClick={() => dialog.current?.close()}>
          Ver a mesa
        </button>
      </header>
      {/* Na corrente, quem decide precisa ver o que já foi ativado. */}
      {props.chain.length > 0 && (
        <ChainStack
          chain={props.chain}
          you={props.you}
          names={props.names}
          cards={props.cards}
          language={props.language}
        />
      )}
      <PromptBody {...props} onCard={setPreview} />
      <ErrorLine error={props.error} />
      <CardText code={preview} cards={props.cards} language={props.language} />
    </dialog>
  );
}

// A carta tocada na mesa e o que dá para fazer com ela agora: os verbos (Invocar, Baixar,
// Ativar...), embaixo de cada um o texto do efeito quando a engine manda, e o texto da carta.
export function CardActionsDialog(
  props: Base & { code: number | null; actions: Command[]; onClose: () => void },
) {
  const open = props.code !== null && props.actions.length > 0;
  const dialog = useModal(open);
  const data = props.code ? props.cards.get(props.code) : undefined;
  const name = data ? displayName(data, props.language) : "Carta";
  return (
    <dialog
      ref={dialog}
      className="duel-dialog card-actions"
      closedby="any"
      aria-labelledby="card-actions-title"
      onClose={props.onClose}
    >
      {open && (
        <>
          <header className="duel-dialog-header">
            <h2 id="card-actions-title">{name}</h2>
          </header>
          <div className="card-actions-body">
            {data?.image !== undefined && (
              <img src={imageUrl(data.image, "m")} alt="" width={134} height={196} />
            )}
            <p className="actions">
              {props.actions.map((item) => (
                <button
                  key={`${item.command}-${item.index}`}
                  type="button"
                  className="cta"
                  disabled={props.pending}
                  onClick={() => {
                    props.onAnswer({ command: item.command, index: item.index });
                    dialog.current?.close();
                  }}
                >
                  {item.verb}
                  {item.card.text && <span className="choice-detail">{item.card.text}</span>}
                </button>
              ))}
              <button type="button" className="secondary" onClick={() => dialog.current?.close()}>
                Cancelar
              </button>
            </p>
          </div>
          <CardText code={props.code} cards={props.cards} language={props.language} />
        </>
      )}
    </dialog>
  );
}

// Todas as ações da fase principal ou da batalha, numa lista (inclusive as de cartas que não
// estão à vista, como no deck).
export function CommandsDialog(
  props: Base & { prompt: Prompt; open: boolean; onClose: () => void },
) {
  const dialog = useModal(props.open);
  return (
    <dialog
      ref={dialog}
      className="duel-dialog"
      closedby="any"
      aria-labelledby="commands-title"
      onClose={props.onClose}
    >
      {props.open && (
        <>
          <header className="duel-dialog-header">
            <h2 id="commands-title">{promptTitle(props.prompt, props)}</h2>
            <button type="button" className="secondary" onClick={() => dialog.current?.close()}>
              Fechar
            </button>
          </header>
          <PromptBody
            {...props}
            onAnswer={(response) => {
              props.onAnswer(response);
              dialog.current?.close();
            }}
          />
        </>
      )}
    </dialog>
  );
}

// Um modal simples, com título e "Fechar": as frases, o histórico e as opções no celular.
export function PlainDialog(props: {
  id: string;
  title: string;
  open: boolean;
  onClose: () => void;
  children: ReactNode;
}) {
  const dialog = useModal(props.open);
  return (
    <dialog
      ref={dialog}
      className="duel-dialog"
      closedby="any"
      aria-labelledby={props.id}
      onClose={props.onClose}
    >
      {props.open && (
        <>
          <header className="duel-dialog-header">
            <h2 id={props.id}>{props.title}</h2>
            <button type="button" className="secondary" onClick={() => dialog.current?.close()}>
              Fechar
            </button>
          </header>
          {props.children}
        </>
      )}
    </dialog>
  );
}
