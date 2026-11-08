import { useState, type ChangeEvent, type FormEvent } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Link, useNavigate } from "react-router";
import { ApiError, request } from "../api.ts";
import { useSession } from "../account/session.ts";
import { useDecks, type Deck } from "./api.ts";

type Created = { data: Deck; meta?: { warnings: string[] } };

// Os decks do jogador: abrir, criar um vazio ou importar de um arquivo (escopo 3.3).
export function DecksPage() {
  const session = useSession();
  const user = session.data?.user;
  const decks = useDecks(Boolean(user));
  const navigate = useNavigate();
  const client = useQueryClient();
  const [kind, setKind] = useState("text");
  const [content, setContent] = useState("");

  // Deck criado: abre no Deck Edit, levando os avisos da importação.
  const open = ({ data, meta }: Created) => {
    client.invalidateQueries({ queryKey: ["decks"] });
    navigate(`/decks/${data.id}`, { state: { warnings: meta?.warnings ?? [] } });
  };
  const create = useMutation({
    mutationFn: () => request<Created>("POST", "/api/decks", { name: "Deck novo", cards: [] }),
    onSuccess: open,
  });
  const importDeck = useMutation({
    mutationFn: () => request<Created>("POST", "/api/decks/import", { name: "", kind, content }),
    onSuccess: open,
  });
  const failure = create.error ?? importDeck.error;

  async function readFile(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    setKind(file.name.toLowerCase().endsWith(".ydk") ? "ydk" : "text");
    setContent(await file.text());
  }

  function submit(event: FormEvent) {
    event.preventDefault();
    importDeck.mutate();
  }

  if (session.isSuccess && !user) {
    return (
      <main className="page narrow">
        <h1>Decks</h1>
        <p>
          <Link to="/entrar">Entre na sua conta</Link> para montar seus decks.
        </p>
      </main>
    );
  }

  return (
    <main className="page">
      <h1>Decks</h1>
      {failure && (
        <p role="alert" className="form-error">
          {failure instanceof ApiError ? failure.message : "Sem conexão. Tente de novo."}
        </p>
      )}
      <p>
        <button
          type="button"
          className="cta"
          disabled={create.isPending}
          onClick={() => create.mutate()}
        >
          Criar deck novo
        </button>
      </p>
      {decks.data && (
        <ul className="deck-list">
          {decks.data.map((deck) => (
            <li key={deck.id}>
              <Link to={`/decks/${deck.id}`}>{deck.name}</Link>
              <span className="muted">
                Main {deck.counts.main} · Extra {deck.counts.extra} · Side {deck.counts.side}
              </span>
            </li>
          ))}
        </ul>
      )}

      <h2>Importar deck</h2>
      <form className="form" onSubmit={submit}>
        <div className="form-field">
          <label htmlFor="deck-file">Arquivo .ydk ou de texto</label>
          <input id="deck-file" type="file" accept=".ydk,.txt,text/plain" onChange={readFile} />
        </div>
        <div className="form-field">
          <label htmlFor="deck-kind">Formato</label>
          <select id="deck-kind" value={kind} onChange={(event) => setKind(event.target.value)}>
            <option value="text">Texto (3 Dark Magician)</option>
            <option value="ydk">.ydk (YGOPro e EDOPro)</option>
          </select>
        </div>
        <div className="form-field">
          <label htmlFor="deck-content">Lista do deck</label>
          <textarea
            id="deck-content"
            rows={8}
            value={content}
            onChange={(event) => setContent(event.target.value)}
          />
        </div>
        <button
          type="submit"
          className="cta"
          disabled={importDeck.isPending || content.trim() === ""}
        >
          Importar
        </button>
      </form>
    </main>
  );
}
