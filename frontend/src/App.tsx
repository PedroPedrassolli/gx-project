import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router";
import { request } from "./api.ts";
import { useSession } from "./account/session.ts";
import { CardImage } from "./catalog/CardImage.tsx";
import type { CardSummary } from "./catalog/cards.ts";
import { nextCharacter, useCharacters, type Character } from "./characters/api.ts";
import { useCollection } from "./collection/api.ts";
import { useShop } from "./shop/api.ts";
import { currentPhase, PHASES } from "./roadmap.ts";
import { usePageTitle } from "./pageTitle.ts";

type Duel = { match_id: number; room_code: string | null };
type ChallengeCount = { done: number; total: number };

// Início (ADR 0015). Com conta, a próxima ação vem primeiro (o duelo em andamento ou o próximo
// personagem) e depois o progresso: coleção, desafios e a loja. Sem conta, o que é o jogo e
// como começar.
export function App() {
  usePageTitle();
  const session = useSession();
  const user = session.data?.user;

  if (user) return <PlayerHome nickname={user.nickname} duel={session.data?.duel ?? null} />;
  if (session.isSuccess) return <VisitorHome />;
  // A sessão ainda não chegou: só o título, para a página não mostrar o que não é dela.
  return (
    <main className="page home">
      <h1>GX Project</h1>
    </main>
  );
}

function PlayerHome({ nickname, duel }: { nickname: string; duel: Duel | null }) {
  const characters = useCharacters(!duel);
  const collection = useCollection(true);
  const challenges = useQuery({
    queryKey: ["challenges"],
    queryFn: async () => (await request<{ data: ChallengeCount }>("GET", "/api/challenges")).data,
  });
  const shop = useShop(true);
  const total = collection.data?.meta.total;
  const newPacks = shop.data?.packs.filter((pack) => pack.new).length ?? 0;

  return (
    <main className="page home">
      <h1>Olá, {nickname}</h1>
      {duel ? (
        <DuelHero matchId={duel.match_id} />
      ) : (
        <ChallengerHero characters={characters.data?.characters} />
      )}

      <div className="home-tiles">
        <Link to="/colecao" className="home-tile">
          <span className="tile-label">Coleção</span>
          <span className="tile-number">{total ? total.owned.toLocaleString("pt-BR") : "…"}</span>
          <span className="tile-label">
            {total ? `de ${total.cards.toLocaleString("pt-BR")} cartas` : "cartas"}
          </span>
          <progress value={total?.owned ?? 0} max={total?.cards || 1} aria-hidden="true" />
        </Link>
        <Link to="/desafios" className="home-tile">
          <span className="tile-label">Desafios</span>
          <span className="tile-number">{challenges.data ? challenges.data.done : "…"}</span>
          <span className="tile-label">
            {challenges.data ? `de ${challenges.data.total} concluídos` : "concluídos"}
          </span>
          <progress
            value={challenges.data?.done ?? 0}
            max={challenges.data?.total || 1}
            aria-hidden="true"
          />
        </Link>
      </div>

      <Link to="/loja" className="home-shop">
        <ShopIcon />
        <span>
          <strong>
            {newPacks > 0
              ? `${newPacks} ${newPacks === 1 ? "pacote novo" : "pacotes novos"} na loja`
              : "Loja de pacotes"}
          </strong>
          <span className="tile-label">
            {shop.data
              ? `Você tem ${shop.data.balance.toLocaleString("pt-BR")} DP para gastar.`
              : "Gaste o DP dos duelos em pacotes."}
          </span>
        </span>
      </Link>

      <Roadmap />
    </main>
  );
}

// O duelo que ficou aberto: o prazo da resposta continua correndo no servidor.
function DuelHero({ matchId }: { matchId: number }) {
  return (
    <section className="home-hero duel" aria-labelledby="hero-title">
      <div>
        <h2 id="hero-title">Você tem um duelo em andamento</h2>
        <p className="muted">O prazo da resposta continua correndo enquanto você está fora.</p>
        <p className="actions">
          <Link className="cta" to={`/duelo/${matchId}`}>
            Voltar para a mesa
          </Link>
        </p>
      </div>
    </section>
  );
}

function ChallengerHero({ characters }: { characters: Character[] | undefined }) {
  // Enquanto a lista chega, o lugar do destaque fica reservado (a página não pula).
  if (!characters) return <div className="home-hero loading" aria-hidden="true" />;
  const next = nextCharacter(characters);
  if (!next) {
    return (
      <section className="home-hero" aria-labelledby="hero-title">
        <div>
          <h2 id="hero-title">Você venceu todos os personagens</h2>
          <p className="muted">Dá para duelar de novo contra qualquer um, ou chamar os amigos.</p>
          <p className="actions">
            <Link className="cta" to="/jogar">
              Jogar
            </Link>
          </p>
        </div>
      </section>
    );
  }
  const card: CardSummary | undefined = next.signature;
  return (
    <section className="home-hero" aria-labelledby="hero-title">
      {card && <CardImage card={card} size="m" width={268} height={391} className="hero-card" />}
      <div>
        <h2 id="hero-title">Próximo desafiante: {next.name}</h2>
        <p className="muted">{next.description}</p>
        {card && (
          <p className="hero-prize">A primeira vitória dá a carta {card.name_pt ?? card.name}.</p>
        )}
      </div>
      <p className="actions hero-actions">
        <Link className="cta" to={`/personagens?duelar=${next.id}`}>
          Duelar contra {next.name}
        </Link>
        <Link className="cta secondary" to="/salas">
          Duelar com amigos
        </Link>
      </p>
    </section>
  );
}

// Algumas cartas da era GX, em leque: só enfeite (a imagem não diz nada que o texto não diga).
const SHOWCASE: CardSummary[] = [
  { id: 1, name: "Winged Kuriboh", image: 57116033 },
  { id: 2, name: "Elemental HERO Flame Wingman", image: 35809262 },
  { id: 3, name: "Elemental HERO Neos", image: 89943723 },
  { id: 4, name: "Cyber End Dragon", image: 1546123 },
  { id: 5, name: "Dark Magician", image: 46986414 },
];

function VisitorHome() {
  return (
    <main className="page home">
      <section className="home-welcome" aria-labelledby="welcome-title">
        <h1 id="welcome-title">GX Project</h1>
        <p className="lead">
          Monte seu deck com as cartas da era GX e duele online com os amigos ou contra os
          personagens do anime.
        </p>
        <p className="actions">
          <Link className="cta" to="/cadastro">
            Criar conta
          </Link>
          <Link className="cta secondary" to="/entrar">
            Entrar
          </Link>
          <Link className="cta secondary" to="/cartas">
            Ver as cartas
          </Link>
        </p>
        <div className="showcase" aria-hidden="true">
          {SHOWCASE.map((card) => (
            <CardImage key={card.id} card={card} size="m" width={268} height={391} />
          ))}
        </div>
      </section>

      <ul className="home-features">
        <li>
          <h2>Contra os personagens</h2>
          <p>O computador joga com os decks do anime, do Chumley ao último chefe.</p>
        </li>
        <li>
          <h2>Com os amigos</h2>
          <p>Crie uma sala, mande o código e duele em tempo real.</p>
        </li>
        <li>
          <h2>Sua coleção</h2>
          <p>Ganhe DP nos duelos, abra pacotes e monte os seus decks.</p>
        </li>
      </ul>

      <Roadmap />
    </main>
  );
}

// O andamento do projeto como as fases de um turno.
function Roadmap() {
  const phase = currentPhase(PHASES);
  return (
    <section aria-labelledby="status-title" className="roadmap">
      <h2 id="status-title">Andamento</h2>
      <p>{phase ? `Fase atual: ${phase.code}, ${phase.name}.` : "Todas as fases terminaram."}</p>
      <ol className="phases">
        {PHASES.map((item) => (
          <li
            key={item.code}
            className={item.done ? "done" : undefined}
            aria-current={item === phase ? "step" : undefined}
          >
            <span className="code">{item.code}</span> {item.name}
          </li>
        ))}
      </ol>
    </section>
  );
}

function ShopIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M6 3h12l1 4H5z" />
      <path d="M5 7h14v14H5z" />
      <path d="M9.5 12h5" />
    </svg>
  );
}
