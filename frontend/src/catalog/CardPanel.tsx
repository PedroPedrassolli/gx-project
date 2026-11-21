import { useEffect, useRef, useSyncExternalStore, type ReactNode } from "react";
import type { Language } from "./cards.ts";
import { useCardDetail, useCatalog } from "./data.ts";
import { Detail } from "./parts.tsx";

// Tela larga o bastante para o detalhe ficar ao lado da lista.
export const WIDE = "(width >= 60rem)";

// A media query como valor do React, que muda quando a tela muda.
export function useMediaQuery(query: string) {
  return useSyncExternalStore(
    (onChange) => {
      const list = matchMedia(query);
      list.addEventListener("change", onChange);
      return () => list.removeEventListener("change", onChange);
    },
    () => matchMedia(query).matches,
  );
}

type Props = {
  cardId: number;
  language: Language;
  packs: Map<number, string>;
  wide: boolean;
  onClose: () => void;
  className?: string;
};

// O detalhe da carta escolhida, igual em todas as páginas. Na tela larga, um painel que a
// página põe ao lado da lista; no celular, um diálogo por cima de tudo, que fecha e devolve
// o lugar na lista. A carta aparece na hora com o que o catálogo já tem (nome, imagem e
// números); só o texto espera o detalhe chegar (GXP-107).
export function CardPanel(props: Props) {
  const detail = useCardDetail(props.cardId);
  const summary = useCatalog().data?.byId.get(props.cardId);
  const card = detail.data ?? summary;
  const pending = detail.data ? undefined : detail.isError ? "failed" : "loading";
  const body = card ? (
    <Detail card={card} pending={pending} language={props.language} packs={props.packs} />
  ) : (
    <h2 id="detail-title">{detail.isError ? "Carta não encontrada." : "Carregando a carta…"}</h2>
  );
  if (!props.wide) return <CardDialog onClose={props.onClose}>{body}</CardDialog>;
  return (
    <section
      className={["card-detail", props.className].filter(Boolean).join(" ")}
      aria-labelledby="detail-title"
    >
      {body}
    </section>
  );
}

// O <dialog> nativo cuida do foco, do Esc e do fundo; clicar fora fecha onde o closedby existe.
function CardDialog(props: { onClose: () => void; children: ReactNode }) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    if (!dialog.current?.open) dialog.current?.showModal();
  }, []);
  return (
    <dialog
      ref={dialog}
      className="card-dialog"
      closedby="any"
      aria-labelledby="detail-title"
      onClose={props.onClose}
    >
      {props.children}
      <form method="dialog">
        <button type="submit" autoFocus>
          Fechar
        </button>
      </form>
    </dialog>
  );
}
