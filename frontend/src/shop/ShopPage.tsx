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
  const [opened, setOpened] = useState<{ pack: ShopPack; openings: DrawnCard[][] } | null>(null);
  const buy = useMutation({
    mutationFn: ({ pack, count }: { pack: ShopPack; count: 1 | 10 }) =>
      buyPacks(pack, count, crypto.randomUUID()),
    onSuccess: (data, { pack }) => {
      setOpened({ pack, openings: data.openings });
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
      {opened ? (
        <Opening pack={opened.pack} openings={opened.openings} onClose={() => setOpened(null)} />
      ) : (
        <>
          {buy.error && (
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
                          aria-describedby={
                            missing(pack, count) > 0 ? `pack-${pack.id}-dp` : undefined
                          }
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
                      <p className="pack-progress">
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
        </>
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

// Os pacotes abertos, um por vez (GXP-108): as cartas do pacote começam viradas e aparecem
// uma por uma (ou todas de uma vez); depois, o mesmo botão abre o próximo pacote. A última
// carta de cada pacote avisa, ainda virada, que sai rara ou melhor.
function Opening(props: { pack: ShopPack; openings: DrawnCard[][]; onClose: () => void }) {
  const catalog = useCatalog();
  const [language] = useCardLanguage();
  const [packIndex, setPackIndex] = useState(0);
  const [shown, setShown] = useState(0);
  const main = useRef<HTMLButtonElement>(null);
  const cards = props.openings[packIndex] ?? [];
  const byId = catalog.data?.byId;
  // As imagens do pacote aberto baixam já, antes de virar, e as do próximo, com prioridade
  // baixa: a carta aparece pronta, sem quadro vazio no meio da virada.
  useEffect(() => {
    if (!byId) return;
    const images = (pack: DrawnCard[] | undefined) => (pack ?? []).map((item) => byId.get(item.id));
    preloadCardImages(images(props.openings[packIndex]), "m");
    preloadCardImages(images(props.openings[packIndex + 1]), "m", "low");
  }, [byId, packIndex, props.openings]);
  const done = shown >= cards.length;
  const last = packIndex === props.openings.length - 1;
  const many = props.openings.length > 1;
  // O botão principal fica no mesmo lugar e muda de papel: virar, abrir o próximo, voltar.
  const action = !done
    ? { label: "Virar a próxima", run: () => setShown(shown + 1) }
    : !last
      ? {
          label: "Abrir o próximo pacote",
          run: () => {
            setPackIndex(packIndex + 1);
            setShown(0);
          },
        }
      : { label: "Voltar para a loja", run: props.onClose };
  return (
    <section className="opening-packs" aria-labelledby="opening-packs-title">
      <h2 id="opening-packs-title">
        {many
          ? `Pacote ${packIndex + 1} de ${props.openings.length}: ${props.pack.name}`
          : props.pack.name}
      </h2>
      <p className="actions">
        <button ref={main} type="button" className="cta" onClick={action.run}>
          {action.label}
        </button>
        {!done && (
          <button
            type="button"
            onClick={() => {
              setShown(cards.length);
              main.current?.focus(); // este botão some: o foco segue no principal
            }}
          >
            Virar todas
          </button>
        )}
        {!(done && last) && (
          <button type="button" onClick={props.onClose}>
            Voltar para a loja
          </button>
        )}
      </p>
      <p role="status" className="opening-count">
        {shown} de {cards.length} cartas viradas.
      </p>
      <ol className="drawn-cards" aria-label="Cartas do pacote">
        {cards.map((drawn, index) => {
          const card = catalog.data?.byId.get(drawn.id);
          const key = `${packIndex}-${index}`;
          if (index >= shown) {
            return (
              <li key={key} className={drawn.rare_slot ? "drawn back rare-slot" : "drawn back"}>
                <span className="drawn-face" />
                <span className="drawn-name">
                  <span className="visually-hidden">Carta virada</span>
                </span>
                <span className="drawn-tags">{drawn.rare_slot && "Rara ou melhor"}</span>
              </li>
            );
          }
          return (
            <li key={key} className={`drawn rarity-${drawn.rarity}`}>
              <CardImage card={card} size="m" width={140} height={204} />
              <span className="drawn-name">{card ? displayName(card, language) : "Carta"}</span>
              <span className="drawn-tags">
                {label(RARITIES, drawn.rarity)}
                {drawn.new && <strong className="new-card">Nova</strong>}
              </span>
            </li>
          );
        })}
      </ol>
    </section>
  );
}
