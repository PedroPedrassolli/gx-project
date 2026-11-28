import { useEffect, useRef, useState } from "react";
import { Link } from "react-router";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useSession } from "../account/session.ts";
import { CardImage, preloadCardImages } from "../catalog/CardImage.tsx";
import { IMAGE_WIDTHS, displayName, type CardSummary } from "../catalog/cards.ts";
import { useCatalog } from "../catalog/data.ts";
import { useCardLanguage } from "../catalog/language.ts";
import { RARITIES, label } from "../catalog/labels.ts";
import { SignInFirst } from "../PageNotice.tsx";
import { usePageTitle } from "../pageTitle.ts";
import { FeaturedCard } from "./Featured.tsx";
import {
  buyPacks,
  markPacksSeen,
  redeemCode,
  shopKey,
  useShop,
  type DrawnCard,
  type ShopPack,
} from "./api.ts";

const number = (value: number) => value.toLocaleString("pt-BR");

// A loja (escopo 3.4 e 4; GXP-86 e GXP-133): a prateleira na ordem do jogo, cada pacote com a
// capa, o preço em DP e, nos bloqueados, a dica e o quanto falta. Comprar abre os pacotes ali
// mesmo, carta por carta.
export function ShopPage() {
  usePageTitle("Loja");
  const session = useSession();
  const user = session.data?.user;
  const shop = useShop(Boolean(user));
  // O catálogo (nome e imagem de cada carta) traz as capas e já fica pronto para a abertura.
  const catalog = useCatalog();
  const client = useQueryClient();
  // A capa de cada pacote: a carta que o catálogo escolheu, já com a imagem.
  const covers = new Map(
    catalog.data?.packs.map((pack) => [
      pack.id,
      pack.cover ? catalog.data?.byId.get(pack.cover) : undefined,
    ]),
  );
  // A compra aberta: os pacotes, o saldo depois dela e um número que muda a cada compra
  // ("Abrir outro" recomeça a abertura do zero).
  const [opened, setOpened] = useState<Opened | null>(null);
  const buy = useMutation({
    mutationFn: ({ pack, count }: { pack: ShopPack; count: 1 | 10 }) =>
      buyPacks(pack, count, crypto.randomUUID()),
    onSuccess: (data, { pack }) => {
      setOpened((old) => ({
        pack,
        openings: data.openings,
        balance: data.balance,
        number: (old?.number ?? 0) + 1,
      }));
      // O saldo mudou (topo e loja) e a coleção ganhou cartas.
      for (const key of [shopKey, ["session"], ["collection"]]) {
        client.invalidateQueries({ queryKey: key });
      }
    },
  });

  // Quanto DP falta para comprar: com saldo curto, o botão desativa e a prateleira diz quanto
  // falta (GXP-117). Antes de o saldo chegar, nada falta.
  const missing = (pack: ShopPack, count: number) =>
    shop.data ? pack.price * count - shop.data.balance : 0;

  // Pacote novo na prateleira: o servidor guarda que o jogador já viu, e o destaque some na
  // próxima visita.
  const hasNew = shop.data?.packs.some((pack) => pack.new) ?? false;
  useEffect(() => {
    if (hasNew) markPacksSeen().catch(() => undefined);
  }, [hasNew]);

  if (session.isSuccess && !user) {
    return <SignInFirst title="Loja" reason="para comprar pacotes" />;
  }

  return (
    <main className="page shop-page">
      <h1>Loja</h1>
      {shop.data && (
        <p className="shop-balance">
          Você tem <strong>{number(shop.data.balance)} DP</strong>. Nível {shop.data.level}.
        </p>
      )}
      {buy.error && !opened && (
        <p role="alert" className="form-error">
          {buy.error.message}
        </p>
      )}
      <ul className="shelf">
        {shop.data?.packs.map((pack) => (
          <li key={pack.id} className={pack.available ? "pack-tile" : "pack-tile locked"}>
            <PackCover card={covers.get(pack.id)} locked={!pack.available} />
            <h2>
              {pack.name}
              {pack.new && (
                <>
                  {" "}
                  <strong className="new-pack">Novo</strong>
                </>
              )}
            </h2>
            <p className="pack-price">
              {number(pack.price)} DP, {pack.cards_per_pack} cartas
            </p>
            {pack.available ? (
              <>
                <p className="pack-buy">
                  {([1, 10] as const).map((count) => (
                    <button
                      key={count}
                      type="button"
                      className={count === 1 ? "cta" : undefined}
                      disabled={buy.isPending || missing(pack, count) > 0}
                      aria-describedby={missing(pack, count) > 0 ? `pack-${pack.id}-dp` : undefined}
                      onClick={() => buy.mutate({ pack, count })}
                    >
                      {count === 1 ? (
                        "Comprar 1"
                      ) : (
                        <>
                          {"Comprar 10 "}
                          <span className="buy-price">({number(pack.price * 10)} DP)</span>
                        </>
                      )}
                    </button>
                  ))}
                </p>
                {missing(pack, 10) > 0 && (
                  <p id={`pack-${pack.id}-dp`} className="pack-hint">
                    {missing(pack, 1) > 0
                      ? `Faltam ${number(missing(pack, 1))} DP para comprar 1.`
                      : `Faltam ${number(missing(pack, 10))} DP para comprar 10.`}
                  </p>
                )}
              </>
            ) : (
              <>
                <p className="pack-hint">{pack.hint}</p>
                {pack.progress !== null && (
                  <p className="unlock-progress">
                    <progress
                      max={100}
                      value={pack.progress}
                      aria-label={`Caminho para liberar ${pack.name}`}
                    />
                    <span aria-hidden="true">{pack.progress}%</span>
                  </p>
                )}
              </>
            )}
          </li>
        ))}
      </ul>
      <section className="converter-link" aria-labelledby="converter-link-title">
        <h2 id="converter-link-title">Conversor de cartas</h2>
        <p>
          Troque de 10 a 99 cartas repetidas por 1 carta.{" "}
          <Link to="/loja/conversor">Abrir o conversor</Link>
        </p>
      </section>
      <SecretCode onUnlocked={() => client.invalidateQueries({ queryKey: shopKey })} />
      {opened && (
        <Opening
          opened={opened}
          buying={buy.isPending}
          error={opened && buy.error ? buy.error.message : undefined}
          onBuyAgain={() => buy.mutate({ pack: opened.pack, count: 1 })}
          onClose={() => {
            setOpened(null);
            buy.reset();
          }}
        />
      )}
    </main>
  );
}

// A capa do pacote (GXP-133): a carta mais rara dele, inclinada sobre a embalagem, e o
// cadeado no bloqueado. É enfeite: o nome do pacote está no título logo embaixo.
function PackCover({ card, locked }: { card: CardSummary | undefined; locked: boolean }) {
  return (
    <span className="pack-cover" aria-hidden="true">
      {card && <CardImage card={card} size="m" width={IMAGE_WIDTHS.m} height={391} lazy />}
      {locked && (
        <svg className="pack-lock" viewBox="0 0 24 24">
          <rect x="5" y="11" width="14" height="10" rx="2" />
          <path d="M8 11V8a4 4 0 0 1 8 0v3" />
        </svg>
      )}
    </span>
  );
}

// Os símbolos do código secreto (escopo 3.4): os botões montam o código, para dar para
// digitar no celular.
const SYMBOLS = ["↑", "↓", "←", "→", "×", "○"];
const SYMBOL_NAMES: Record<string, string> = {
  "↑": "Cima",
  "↓": "Baixo",
  "←": "Esquerda",
  "→": "Direita",
  "×": "Xis",
  "○": "Círculo",
};

function SecretCode({ onUnlocked }: { onUnlocked: () => void }) {
  const [code, setCode] = useState("");
  const redeem = useMutation({
    mutationFn: () => redeemCode(code),
    onSuccess: () => {
      setCode("");
      onUnlocked();
    },
  });
  return (
    <section aria-labelledby="secret-code-title" className="secret-code">
      <h2 id="secret-code-title">Código secreto</h2>
      <p className="hint">Alguns pacotes só aparecem para quem sabe o código.</p>
      <p className="code-typed" role="status" aria-label="Código digitado">
        {code || "…"}
      </p>
      <div className="code-keys" role="group" aria-label="Símbolos do código">
        {SYMBOLS.map((symbol) => (
          <button
            key={symbol}
            type="button"
            aria-label={SYMBOL_NAMES[symbol]}
            disabled={code.length >= 16}
            onClick={() => setCode(code + symbol)}
          >
            {symbol}
          </button>
        ))}
      </div>
      {code.length >= 16 && <p className="hint">O código tem no máximo 16 símbolos.</p>}
      <p className="actions">
        <button
          type="button"
          className="cta"
          disabled={code === "" || redeem.isPending}
          onClick={() => redeem.mutate()}
        >
          Enviar o código
        </button>
        <button type="button" disabled={code === ""} onClick={() => setCode("")}>
          Apagar
        </button>
      </p>
      {redeem.data && <p role="status">Pacote liberado: {redeem.data.join(" e ")}.</p>}
      {redeem.error && (
        <p role="alert" className="form-error">
          {redeem.error.message}
        </p>
      )}
    </section>
  );
}

type Opened = { pack: ShopPack; openings: DrawnCard[][]; balance: number; number: number };

// A abertura em tela cheia (GXP-138), num <dialog>: o Esc e o "×" fecham e o foco fica dentro.
// O que muda a cada compra fica no Packs, que recomeça quando chega uma compra nova.
function Opening(props: {
  opened: Opened;
  buying: boolean;
  error?: string;
  onBuyAgain: () => void;
  onClose: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const element = dialog.current;
    if (element && !element.open) element.showModal();
    element?.querySelector<HTMLButtonElement>("button.card-back")?.focus();
  }, []);
  return (
    <dialog
      ref={dialog}
      className="pack-dialog"
      aria-labelledby="opening-title"
      onClose={props.onClose}
    >
      <Packs key={props.opened.number} {...props} />
    </dialog>
  );
}

// Ordem das raridades, da mais comum para a mais rara.
const RANK = ["common", "rare", "super_rare", "ultra_rare"];

// A carta que vai para o meio: a mais rara do pacote; no empate, a última (a de raridade
// aumentada, que fecha o pacote).
function featuredIndex(cards: DrawnCard[]) {
  let best = 0;
  let bestRank = -1;
  cards.forEach((card, index) => {
    const rank = RANK.indexOf(card.rarity);
    if (rank >= bestRank) {
      best = index;
      bestRank = rank;
    }
  });
  return best;
}

// Os pacotes da compra, um por vez: todas as cartas começam viradas, a mais rara no meio e
// grande. Toque em cada uma para ver, ou "Virar todas"; depois, o mesmo lugar abre o próximo
// pacote ou, no último, "Abrir outro" compra mais um do mesmo pacote.
function Packs(props: { opened: Opened; buying: boolean; error?: string; onBuyAgain: () => void }) {
  const { pack, openings, balance } = props.opened;
  const catalog = useCatalog();
  const [language] = useCardLanguage();
  const [packIndex, setPackIndex] = useState(0);
  const [flipped, setFlipped] = useState<Set<number>>(new Set());
  const list = useRef<HTMLOListElement>(null);
  const action = useRef<HTMLButtonElement>(null);
  // O botão da carta que virou some: depois de cada virada, o foco vai para a próxima carta
  // ainda virada ou, no fim, para o botão principal. Dá para abrir tudo no Enter.
  const moveFocus = useRef(true);
  useEffect(() => {
    if (!moveFocus.current) return;
    moveFocus.current = false;
    (list.current?.querySelector<HTMLButtonElement>("button.card-back") ?? action.current)?.focus();
  });
  const cards = openings[packIndex] ?? [];
  const byId = catalog.data?.byId;
  // As imagens do pacote aberto baixam já, antes de virar, e as do próximo, com prioridade
  // baixa: a carta aparece pronta, sem quadro vazio no meio da virada.
  useEffect(() => {
    if (!byId) return;
    const images = (drawn: DrawnCard[] | undefined) =>
      (drawn ?? []).map((item) => byId.get(item.id));
    preloadCardImages(images(openings[packIndex]), "m");
    preloadCardImages(images(openings[packIndex + 1]), "m", "low");
  }, [byId, packIndex, openings]);

  const flip = (indexes: number[]) => {
    moveFocus.current = true;
    setFlipped((old) => new Set([...old, ...indexes]));
  };
  const featured = featuredIndex(cards);
  const done = flipped.size >= cards.length;
  const last = packIndex === openings.length - 1;
  const missing = pack.price - balance;
  return (
    <div className="pack-screen">
      <header className="pack-head">
        <div>
          <h2 id="opening-title">
            {openings.length > 1
              ? `Pacote ${packIndex + 1} de ${openings.length}: ${pack.name}`
              : pack.name}
          </h2>
          <p className="muted">Pacote de {cards.length} cartas</p>
        </div>
        <form method="dialog">
          <button type="submit" className="close-button" aria-label="Fechar o pacote">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M6 6l12 12M18 6 6 18" />
            </svg>
          </button>
        </form>
      </header>
      <p role="status" className="visually-hidden">
        {flipped.size} de {cards.length} cartas viradas.
      </p>

      <ol ref={list} className="pack-cards" aria-label="Cartas do pacote">
        {cards.map((drawn, index) => {
          const card = byId?.get(drawn.id);
          const name = card ? displayName(card, language) : "Carta";
          const classes = ["drawn", index === featured && "featured", `rarity-${drawn.rarity}`];
          if (!flipped.has(index)) {
            return (
              <li key={`${packIndex}-${index}`} className={classes.filter(Boolean).join(" ")}>
                <button
                  type="button"
                  className="card-back"
                  aria-label={`Virar a carta ${index + 1}`}
                  onClick={() => flip([index])}
                />
                <span className="drawn-tags">
                  {drawn.rare_slot ? "Rara ou melhor" : "Toque para virar"}
                </span>
              </li>
            );
          }
          if (index === featured) {
            return (
              <li key={`${packIndex}-${index}`} className={classes.filter(Boolean).join(" ")}>
                <FeaturedCard card={card} name={name} rarity={drawn.rarity} isNew={drawn.new} />
              </li>
            );
          }
          return (
            <li key={`${packIndex}-${index}`} className={classes.filter(Boolean).join(" ")}>
              <span className="face">
                <CardImage card={card} size="m" width={IMAGE_WIDTHS.m} height={391} alt={name} />
              </span>
              <span className="drawn-tags">
                <span className={`rarity rarity-${drawn.rarity}`}>
                  {label(RARITIES, drawn.rarity)}
                </span>
                {drawn.new && <strong className="new-card">Nova</strong>}
              </span>
            </li>
          );
        })}
      </ol>

      <div className="pack-actions">
        {!done ? (
          <button ref={action} type="button" onClick={() => flip(cards.map((_, index) => index))}>
            Virar todas
          </button>
        ) : !last ? (
          <button
            ref={action}
            type="button"
            className="cta"
            onClick={() => {
              moveFocus.current = true;
              setPackIndex(packIndex + 1);
              setFlipped(new Set());
            }}
          >
            Abrir o próximo pacote
          </button>
        ) : (
          <button
            ref={action}
            type="button"
            className="cta"
            disabled={props.buying || missing > 0}
            aria-describedby={missing > 0 ? "open-another-dp" : undefined}
            onClick={props.onBuyAgain}
          >
            {props.buying ? "Abrindo…" : `Abrir outro (${number(pack.price)} DP)`}
          </button>
        )}
        {props.error && (
          <p role="alert" className="form-error">
            {props.error}
          </p>
        )}
        <p className="muted">
          Saldo: {number(balance)} DP. As cartas já estão na sua coleção.
          {done && last && missing > 0 && (
            <span id="open-another-dp"> Faltam {number(missing)} DP para abrir outro.</span>
          )}
        </p>
      </div>
    </div>
  );
}
