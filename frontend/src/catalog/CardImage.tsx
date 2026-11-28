import { useEffect, useState } from "react";
import { IMAGE_WIDTHS, imageUrl, type CardSummary } from "./cards.ts";

// Espera antes de cada nova tentativa: a rede do celular derruba um pedido de vez em quando,
// e a imagem não pode sumir por causa disso.
const RETRIES = [800, 2500];

type Props = {
  card: CardSummary | undefined;
  size: "p" | "m";
  width: number;
  height: number;
  alt?: string; // vazio quando o nome já está do lado da imagem
  className?: string;
  lazy?: boolean; // só nas listas longas, para não baixar o que está fora da tela
  zoom?: boolean; // no detalhe: a imagem grande (g) nas telas de alta densidade
  ifMissing?: "face" | "nothing"; // "nothing" quando já há outra imagem por baixo
};

// A imagem de uma carta, igual em todas as telas. Nunca um quadro vazio (GXP-142): enquanto
// a imagem chega, o lugar já mostra o verso da carta; se o pedido falha, o verso fica e as
// novas tentativas seguem por trás (se uma der certo, a imagem volta).
export function CardImage(props: Props) {
  const { card, size } = props;
  const src = card?.image === undefined ? undefined : imageUrl(card.image, size);
  // failures: quantas vezes o pedido falhou; recovered: uma nova tentativa deu certo.
  const [attempt, setAttempt] = useState({ src, failures: 0, recovered: false });
  // Outra carta no mesmo lugar (a lista mudou, o pacote seguinte): começa do zero.
  if (attempt.src !== src) setAttempt({ src, failures: 0, recovered: false });
  const { failures } = attempt;
  const retrying = failures > 0 && !attempt.recovered;

  useEffect(() => {
    const wait = RETRIES[failures - 1];
    if (!src || !retrying || wait === undefined) return;
    let current = true;
    const update = (change: Partial<typeof attempt>) => {
      if (current) setAttempt((old) => (old.src === src ? { ...old, ...change } : old));
    };
    const timer = setTimeout(() => {
      const image = new Image();
      image.onload = () => update({ recovered: true });
      image.onerror = () => update({ failures: failures + 1 });
      image.src = retryUrl(src, failures);
    }, wait);
    return () => {
      current = false;
      clearTimeout(timer);
    };
  }, [src, retrying, failures]);

  if (!src || retrying) {
    if (props.ifMissing === "nothing") return null;
    return <CardPlaceholder alt={props.alt} className={props.className} />;
  }
  // A imagem que voltou usa o mesmo endereço da tentativa que deu certo: vem do cache.
  const retry = (url: string) => retryUrl(url, failures);
  // Por baixo da imagem que ainda não chegou, o verso. Não na imagem grande do detalhe
  // ("nothing"): ali a miniatura que já chegou fica à vista por baixo.
  const classes = [props.className, props.ifMissing !== "nothing" && "card-img"];
  return (
    <img
      className={classes.filter(Boolean).join(" ") || undefined}
      src={retry(src)}
      srcSet={
        props.zoom && card?.image !== undefined
          ? `${retry(imageUrl(card.image, "m"))} ${IMAGE_WIDTHS.m}w, ${retry(imageUrl(card.image, "g"))} ${IMAGE_WIDTHS.g}w`
          : undefined
      }
      sizes={props.zoom ? `${IMAGE_WIDTHS.m}px` : undefined}
      alt={props.alt ?? ""}
      width={props.width}
      height={props.height}
      loading={props.lazy ? "lazy" : undefined}
      decoding="async"
      onError={() =>
        setAttempt((old) =>
          old.src === src ? { ...old, failures: old.failures + 1, recovered: false } : old,
        )
      }
    />
  );
}

// A nova tentativa muda o endereço (?tentativa=1): o navegador não reaproveita o erro.
function retryUrl(url: string, attempt: number) {
  return attempt ? `${url}?tentativa=${attempt}` : url;
}

// O verso da carta no lugar da imagem que não veio (GXP-142): toda carta parece uma carta.
// O nome fica no texto alternativo, para o leitor de tela.
function CardPlaceholder(props: { alt?: string; className?: string }) {
  return (
    <span
      className={["card-placeholder", props.className].filter(Boolean).join(" ")}
      role={props.alt ? "img" : undefined}
      aria-label={props.alt || undefined}
      aria-hidden={props.alt ? undefined : true}
    />
  );
}

// Baixa as imagens antes de aparecerem (as cartas do pacote, antes de virar): quando a carta
// aparece, a imagem já está no cache e surge na hora. "low" para o que vem depois, para não
// disputar a rede com o que está na tela.
const preloading = new Set<HTMLImageElement>();

export function preloadCardImages(
  cards: (CardSummary | undefined)[],
  size: "p" | "m",
  priority: "high" | "low" = "high",
) {
  for (const card of cards) {
    if (card?.image === undefined) continue;
    const image = new Image();
    if (priority === "low") image.fetchPriority = "low";
    // Guardada até terminar, para o navegador não largar o pedido no meio.
    const done = () => preloading.delete(image);
    image.onload = done;
    image.onerror = done;
    preloading.add(image);
    image.src = imageUrl(card.image, size);
  }
}
