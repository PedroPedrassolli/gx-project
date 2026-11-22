import { useState } from "react";
import { Link } from "react-router";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useSession } from "../account/session.ts";
import { CardImage } from "../catalog/CardImage.tsx";
import { displayName, type CardSummary } from "../catalog/cards.ts";
import { CardTile } from "../catalog/parts.tsx";
import { useCatalog } from "../catalog/data.ts";
import { useCardLanguage } from "../catalog/language.ts";
import { SignInFirst } from "../PageNotice.tsx";
import { usePageTitle } from "../pageTitle.ts";
import { converterKey, convertCards, useConverter, useConverterGroup } from "./api.ts";

// O conversor de cartas (escopo 3.4; GXP-90): o jogador escolhe de 10 a 99 cópias repetidas
// e troca por 1 carta sorteada do grupo dessa quantidade. Só aparecem as cópias que dá para
// trocar: uma de cada carta e as que os decks usam ficam sempre (o servidor confere de novo).
export function ConverterPage() {
  usePageTitle("Conversor de cartas");
  const session = useSession();
  const user = session.data?.user;
  const converter = useConverter(Boolean(user));
  const catalog = useCatalog();
  const [language] = useCardLanguage();
  const client = useQueryClient();
  const [chosen, setChosen] = useState<Record<number, number>>({});
  const convert = useMutation({
    mutationFn: () => convertCards(chosen, crypto.randomUUID()),
    onSuccess: () => {
      setChosen({});
      for (const key of [converterKey, ["collection"]]) {
        client.invalidateQueries({ queryKey: key });
      }
    },
  });

  if (session.isSuccess && !user) {
    return <SignInFirst title="Conversor de cartas" reason="para trocar cartas repetidas" />;
  }

  const data = converter.data;
  const total = Object.values(chosen).reduce((sum, quantity) => sum + quantity, 0);
  const ready = data !== undefined && total >= data.min && total <= data.max;
  // Quanto ainda cabe até o máximo: no máximo, "+" e "Todas" desativam (GXP-117).
  const room = data ? data.max - total : 0;
  const rows = (data?.cards ?? [])
    .map((row) => ({ ...row, card: catalog.data?.byId.get(row.card_id) }))
    .filter((row): row is typeof row & { card: CardSummary } => row.card !== undefined)
    .sort((a, b) => displayName(a.card, language).localeCompare(displayName(b.card, language)));
  const choose = (id: number, quantity: number) => setChosen({ ...chosen, [id]: quantity });

  if (convert.data) {
    const card = catalog.data?.byId.get(convert.data.card_id);
    return (
      <main className="page narrow converter-page">
        <h1>Conversor de cartas</h1>
        <section className="converted" aria-labelledby="converted-title">
          <h2 id="converted-title">Você trocou {convert.data.amount} cartas por:</h2>
          <CardImage card={card} size="m" width={140} height={204} className="converted-image" />
          <p className="converted-name">
            {card ? displayName(card, language) : "Carta"}
            {convert.data.new && <strong className="new-card">Nova</strong>}
          </p>
          <p className="actions">
            <button type="button" className="cta" onClick={() => convert.reset()}>
              Converter de novo
            </button>
            <Link to="/loja">Voltar para a loja</Link>
          </p>
        </section>
      </main>
    );
  }

  return (
    <main className="page narrow converter-page">
      <h1>Conversor de cartas</h1>
      <p>
        Troque de {data?.min ?? 10} a {data?.max ?? 99} cartas repetidas por 1 carta. A quantidade
        escolhe o grupo de cartas que pode sair. Você sempre fica com uma cópia de cada carta e com
        as que os seus decks usam.
      </p>
      {data && rows.length === 0 && catalog.data && (
        <p className="notice">
          Você ainda não tem cartas repetidas para trocar. <Link to="/loja">Abra pacotes</Link>.
        </p>
      )}
      {rows.length > 0 && (
        <>
          <div className="converter-summary">
            <p role="status">
              {total === 0
                ? "Nenhuma carta escolhida."
                : `${total} ${total === 1 ? "carta escolhida" : "cartas escolhidas"}.`}
              {data && total > 0 && total < data.min && ` Faltam ${data.min - total}.`}
              {data && total >= data.max && ` Chegou ao máximo de ${data.max}.`}
            </p>
            <p className="actions">
              <button
                type="button"
                className="cta"
                disabled={!ready || convert.isPending}
                onClick={() => convert.mutate()}
              >
                {ready ? `Converter ${total} cartas` : "Converter"}
              </button>
              <button type="button" disabled={total === 0} onClick={() => setChosen({})}>
                Limpar
              </button>
            </p>
          </div>
          {ready && <Group amount={total} language={language} />}
          {convert.error && (
            <p role="alert" className="form-error">
              {convert.error.message}
            </p>
          )}
          {/* A mesma grade da coleção e do deck (GXP-133): a carta com as repetidas por cima e,
              embaixo, quantas entram na troca. */}
          <ul className="card-grid converter-cards">
            {rows.map(({ card, quantity: spare }) => {
              const name = displayName(card, language);
              const count = chosen[card.id] ?? 0;
              return (
                <li key={card.id} className={count > 0 ? "chosen" : undefined}>
                  <CardTile card={card} language={language}>
                    <span className="badge">
                      {spare} {spare === 1 ? "repetida" : "repetidas"}
                    </span>
                  </CardTile>
                  <span className="converter-count" role="group" aria-label={`Cópias de ${name}`}>
                    <button
                      type="button"
                      aria-label={`Uma a menos de ${name}`}
                      disabled={count === 0}
                      onClick={() => choose(card.id, count - 1)}
                    >
                      −
                    </button>
                    <output aria-live="off">{count}</output>
                    <button
                      type="button"
                      aria-label={`Uma a mais de ${name}`}
                      disabled={count >= spare || room <= 0}
                      onClick={() => choose(card.id, count + 1)}
                    >
                      +
                    </button>
                    <button
                      type="button"
                      className="converter-all"
                      aria-label={`Todas as ${spare} repetidas de ${name}`}
                      disabled={count >= spare || room <= 0}
                      onClick={() => choose(card.id, Math.min(spare, count + room))}
                    >
                      Todas
                    </button>
                  </span>
                </li>
              );
            })}
          </ul>
        </>
      )}
    </main>
  );
}

// As cartas que podem sair com essa quantidade: só busca quando o jogador abre a lista.
function Group({ amount, language }: { amount: number; language: "pt" | "en" }) {
  const [open, setOpen] = useState(false);
  const group = useConverterGroup(amount, open);
  const catalog = useCatalog();
  const names = (group.data ?? [])
    .map((id) => catalog.data?.byId.get(id))
    .filter((card) => card !== undefined)
    .map((card) => displayName(card, language))
    .sort((a, b) => a.localeCompare(b));
  return (
    <details className="converter-group" onToggle={(event) => setOpen(event.currentTarget.open)}>
      <summary>Ver as cartas que podem sair com {amount}</summary>
      {group.isPending && open && <p role="status">Carregando…</p>}
      {names.length > 0 && (
        <ul>
          {names.map((name) => (
            <li key={name}>{name}</li>
          ))}
        </ul>
      )}
    </details>
  );
}
