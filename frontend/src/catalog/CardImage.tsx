import { useState } from "react";
import { displayName, frame, IMAGE_WIDTHS, imageUrl, type CardSummary } from "./cards.ts";
import { useCardLanguage } from "./language.ts";

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

// A imagem de uma carta, igual em todas as telas. Se o pedido falha, tenta de novo duas
// vezes; se ainda assim não vier, ou se a carta não tem imagem (as do anime), aparece a face
// com o nome na cor da moldura: nunca um quadro vazio.
export function CardImage(props: Props) {
  const { card, size } = props;
  const src = card?.image === undefined ? undefined : imageUrl(card.image, size);
  const [attempt, setAttempt] = useState({ src, number: 0, failed: false });
  // Outra carta no mesmo lugar (a lista mudou, o pacote seguinte): começa do zero.
  if (attempt.src !== src) setAttempt({ src, number: 0, failed: false });

  if (!src || attempt.failed) {
    if (props.ifMissing === "nothing") return null;
    return <CardFace card={card} alt={props.alt} className={props.className} />;
  }
  // A nova tentativa muda o endereço (?tentativa=1): o navegador não reaproveita o erro.
  const retry = (url: string) => (attempt.number ? `${url}?tentativa=${attempt.number}` : url);
  const onError = () => {
    const wait = RETRIES[attempt.number];
    if (wait === undefined) {
      setAttempt((current) => ({ ...current, failed: true }));
      return;
    }
    setTimeout(() => {
      setAttempt((current) =>
        current.src === src ? { ...current, number: current.number + 1 } : current,
      );
    }, wait);
  };
  return (
    <img
      className={props.className}
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
      onError={onError}
    />
  );
}

// A face da carta sem imagem: a cor da moldura e o nome (que some quando a face é pequena
// demais para ler, como nas miniaturas de 28 px).
function CardFace(props: { card: CardSummary | undefined; alt?: string; className?: string }) {
  const [language] = useCardLanguage();
  const { card } = props;
  const classes = ["card-face", card && `frame-${frame(card)}`, props.className];
  return (
    <span
      className={classes.filter(Boolean).join(" ")}
      role={props.alt ? "img" : undefined}
      aria-label={props.alt || undefined}
      aria-hidden={props.alt ? undefined : true}
    >
      {card && <span className="card-face-name">{displayName(card, language)}</span>}
    </span>
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
