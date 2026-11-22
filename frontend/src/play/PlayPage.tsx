import { Link } from "react-router";
import { useSession } from "../account/session.ts";
import { useCharacters } from "../characters/api.ts";
import { usePageTitle } from "../pageTitle.ts";
import { useOpenRooms } from "../rooms/api.ts";
import { RoomCard } from "../rooms/RoomCard.tsx";
import { ChallengerHero } from "./ChallengerHero.tsx";

// Jogar (ADR 0015; GXP-134): primeiro o próximo personagem, pronto para duelar; depois as
// salas abertas agora, para entrar direto; e as duas formas de duelar, para ver tudo. O duelo
// em andamento já aparece no aviso do topo, em qualquer página.
export function PlayPage() {
  usePageTitle("Jogar");
  const user = useSession().data?.user;
  const characters = useCharacters(Boolean(user));
  const rooms = useOpenRooms(Boolean(user));
  const open = rooms.data ?? [];

  return (
    <main className="page play">
      <h1>Jogar</h1>
      {user && <ChallengerHero characters={characters.data?.characters} friends={false} />}

      {user && (
        <section aria-labelledby="open-rooms-title" className="play-rooms">
          <h2 id="open-rooms-title">Salas abertas</h2>
          {rooms.isSuccess && open.length === 0 && (
            <p className="muted">
              Nenhuma sala aberta agora. <Link to="/salas">Crie uma</Link> e mande o código para um
              amigo.
            </p>
          )}
          {open.length > 0 && (
            <>
              <ul className="room-cards">
                {open.slice(0, 3).map((room) => (
                  <RoomCard key={room.code} room={room} />
                ))}
              </ul>
              <p>
                <Link to="/salas">
                  {open.length > 3 ? `Ver as ${open.length} salas` : "Criar ou entrar com o código"}
                </Link>
              </p>
            </>
          )}
        </section>
      )}

      <ul className="play-options">
        <li>
          <Link to="/personagens" className="play-option">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <circle cx="9" cy="7" r="3.5" />
              <path d="M2.5 20c0-4 2.9-6.5 6.5-6.5s6.5 2.5 6.5 6.5" />
              <rect x="15" y="6" width="6" height="9" rx="1" transform="rotate(12 18 10.5)" />
            </svg>
            <span className="play-title">Contra os personagens</span>
            <span className="play-text">
              O computador joga com os decks do anime. Vencer libera o próximo, e a primeira vitória
              contra cada um dá a carta dele.
            </span>
          </Link>
        </li>
        <li>
          <Link to="/salas" className="play-option">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <circle cx="7" cy="8" r="3" />
              <circle cx="17" cy="8" r="3" />
              <path d="M1.5 19c0-3.3 2.4-5.5 5.5-5.5s5.5 2.2 5.5 5.5M11.5 19c0-3.3 2.4-5.5 5.5-5.5s5.5 2.2 5.5 5.5" />
            </svg>
            <span className="play-title">Com os amigos</span>
            <span className="play-text">
              Crie uma sala e mande o código, ou entre numa sala aberta. Para uma melhor de 3, é só
              jogar a revanche.
            </span>
          </Link>
        </li>
      </ul>
    </main>
  );
}
