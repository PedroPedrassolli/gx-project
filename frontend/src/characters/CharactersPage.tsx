import { useEffect, useRef, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Link, useNavigate, useSearchParams } from "react-router";
import { SESSION_KEY, useSession } from "../account/session.ts";
import { CardImage } from "../catalog/CardImage.tsx";
import { IMAGE_WIDTHS, displayName } from "../catalog/cards.ts";
import { catalogQuery } from "../catalog/data.ts";
import { useCardLanguage } from "../catalog/language.ts";
import { useDecks, type DeckSummary } from "../decks/api.ts";
import { deckSizeProblem } from "../decks/deck.ts";
import { SignInFirst } from "../PageNotice.tsx";
import { usePageTitle } from "../pageTitle.ts";
import {
  byGroup,
  charactersKey,
  nextCharacter,
  startDuel,
  useCharacters,
  type Character,
} from "./api.ts";

const DECK_KEY = "gx-deck-contra-personagens";

// Os personagens para duelar contra o computador (escopo 3.10; ADR 0013), na ordem em que são
// liberados. "Duelar" abre o modal do deck; o endereço guarda quem foi escolhido
// (?duelar=chumley), para o "Duelar de novo" do resultado abrir direto o modal.
export function CharactersPage() {
  usePageTitle("Personagens");
  const session = useSession();
  const user = session.data?.user;
  const characters = useCharacters(Boolean(user));
  const decks = useDecks(Boolean(user));
  const [params, setParams] = useSearchParams();
  const client = useQueryClient();
  // Enquanto o jogador escolhe, chega o que o duelo vai usar: o catálogo (nome e imagem das
  // cartas da mesa) e o código da tela do duelo. A mesa abre pronta (GXP-107).
  useEffect(() => {
    void client.prefetchQuery(catalogQuery);
    void import("../duel/DuelPage.tsx");
  }, [client]);

  if (session.isSuccess && !user) {
    return <SignInFirst title="Personagens" reason="para duelar contra os personagens" />;
  }
  const data = characters.data;
  const chosen = data?.characters.find(
    (character) => character.id === params.get("duelar") && character.status !== "locked",
  );
  const next = data && nextCharacter(data.characters);

  return (
    <main className="page characters-page">
      <h1>Personagens</h1>
      <p className="lead">
        Duele contra o computador com os decks dos personagens do anime. Vencer um libera o próximo,
        e a primeira vitória contra cada um dá a carta dele.
      </p>
      {characters.isError && (
        <p role="alert" className="form-error">
          Não deu para carregar os personagens. Tente de novo daqui a pouco.
        </p>
      )}
      {data &&
        byGroup(data.characters).map((group) => (
          <section key={group.id} aria-labelledby={`grupo-${group.id}`}>
            <h2 id={`grupo-${group.id}`}>{group.name}</h2>
            <ol className="characters" start={group.characters[0]?.position}>
              {group.characters.map((character) => (
                <CharacterItem
                  key={character.id}
                  character={character}
                  next={character.id === next?.id}
                  onDuel={() => setParams({ duelar: character.id })}
                />
              ))}
            </ol>
          </section>
        ))}
      {chosen && (
        <DeckDialog
          character={chosen}
          decks={decks.data}
          onClose={() => setParams({}, { replace: true })}
        />
      )}
    </main>
  );
}

// Um degrau da escada (GXP-134): o número (ou o ✓ de quem já foi vencido), a carta do prêmio
// grande e o texto. O próximo a vencer ganha o destaque.
function CharacterItem(props: { character: Character; next: boolean; onDuel: () => void }) {
  const { character, onDuel } = props;
  const [language] = useCardLanguage();
  const card = character.signature;
  const cardName = card ? displayName(card, language) : null;
  return (
    <li className={`character ${character.status}${props.next ? " next" : ""}`}>
      {/* O número do degrau só para quem vê: a lista numerada já diz a posição. */}
      <span className="character-step" aria-hidden="true">
        {character.status === "beaten" ? "✓" : character.position}
      </span>
      <span className="character-card">
        <CardImage card={card} size="m" width={IMAGE_WIDTHS.m} height={391} lazy />
      </span>
      <div className="character-text">
        {props.next && <p className="character-next">Próximo desafio</p>}
        <h3>{character.name}</h3>
        <p>{character.description}</p>
        <p className="hint">
          {cardName && <>Primeira vitória: a carta {cardName}. </>}
          Toda vitória: +{character.bonus} DP.
        </p>
      </div>
      <div className="character-action">
        {character.status === "locked" ? (
          <p className="character-lock">{character.unlock_hint}</p>
        ) : (
          <>
            {character.status === "beaten" && (
              <p className="character-wins">
                Vencido {character.wins === 1 ? "1 vez" : `${character.wins} vezes`}
              </p>
            )}
            <button type="button" className="cta" onClick={onDuel}>
              Duelar<span className="visually-hidden"> contra {character.name}</span>
            </button>
          </>
        )}
      </div>
    </li>
  );
}

function savedDeck() {
  try {
    return localStorage.getItem(DECK_KEY) ?? "";
  } catch {
    return "";
  }
}

// O modal do deck: escolhe com qual deck duelar e começa. Lembra o último deck usado neste
// navegador.
function DeckDialog(props: {
  character: Character;
  decks: DeckSummary[] | undefined;
  onClose: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const navigate = useNavigate();
  const client = useQueryClient();
  const [deckId, setDeckId] = useState(savedDeck);
  const decks = props.decks ?? [];
  const chosen = decks.some((deck) => String(deck.id) === deckId)
    ? deckId
    : String(decks[0]?.id ?? "");
  // Com outro duelo em andamento ou com um deck que já não vale pela contagem, o duelo não
  // começa; o modal diz o porquê e leva aonde resolver (GXP-117).
  const duel = useSession().data?.duel;
  const chosenDeck = decks.find((deck) => String(deck.id) === chosen);
  const problem = chosenDeck && deckSizeProblem(chosenDeck.counts);
  const start = useMutation({
    mutationFn: () => startDuel(props.character.id, chosen),
    onSuccess: (matchId) => {
      try {
        localStorage.setItem(DECK_KEY, chosen);
      } catch {
        // Sem armazenamento (aba anônima, por exemplo): na próxima, o primeiro deck.
      }
      client.invalidateQueries({ queryKey: charactersKey });
      client.invalidateQueries({ queryKey: SESSION_KEY });
      navigate(`/duelo/${matchId}`);
    },
  });

  useEffect(() => {
    if (!dialog.current?.open) dialog.current?.showModal();
  }, []);

  return (
    <dialog
      ref={dialog}
      className="duel-dialog deck-dialog"
      closedby="any"
      aria-labelledby="deck-dialog-title"
      onClose={props.onClose}
    >
      <h2 id="deck-dialog-title">Duelar contra {props.character.name}</h2>
      <p className="hint">
        Deck dele: {props.character.deck}. Sem relógio e sem banlist, dos dois lados.
      </p>
      {props.decks && decks.length === 0 ? (
        <p>
          Você ainda não tem deck. <Link to="/decks">Monte um deck</Link> para duelar.
        </p>
      ) : (
        <form
          id="deck-form"
          className="form"
          onSubmit={(event) => {
            event.preventDefault();
            start.mutate();
          }}
        >
          <div className="form-field">
            <label htmlFor="character-deck">Seu deck</label>
            <select
              id="character-deck"
              value={chosen}
              onChange={(event) => setDeckId(event.target.value)}
            >
              {decks.map((deck) => (
                <option key={deck.id} value={deck.id}>
                  {deck.name}
                </option>
              ))}
            </select>
          </div>
          {duel ? (
            <p id="deck-reason" className="hint">
              Termine o duelo em andamento antes de começar outro.{" "}
              <Link to={`/duelo/${duel.match_id}`}>Voltar para a mesa</Link>
            </p>
          ) : (
            problem &&
            chosenDeck && (
              <p id="deck-reason" className="hint">
                {problem} <Link to={`/decks/${chosenDeck.id}`}>Abrir no Deck Edit</Link>
              </p>
            )
          )}
          {start.error && (
            <p role="alert" className="form-error">
              {start.error.message}
            </p>
          )}
        </form>
      )}
      <p className="actions">
        {decks.length > 0 && (
          <button
            type="submit"
            form="deck-form"
            className="cta"
            disabled={start.isPending || Boolean(duel || problem)}
            aria-describedby={duel || problem ? "deck-reason" : undefined}
          >
            {start.isPending ? "Começando…" : "Começar o duelo"}
          </button>
        )}
        <button type="button" className="secondary" onClick={() => dialog.current?.close()}>
          Cancelar
        </button>
      </p>
    </dialog>
  );
}
