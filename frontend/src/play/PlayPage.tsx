import { Link } from "react-router";
import { usePageTitle } from "../pageTitle.ts";

// Jogar (ADR 0015): as duas formas de duelar num lugar só. Contra os personagens, o computador
// joga com os decks do anime; com os amigos, numa sala com código. O duelo em andamento já
// aparece no aviso do topo, em qualquer página.
export function PlayPage() {
  usePageTitle("Jogar");

  return (
    <main className="page play">
      <h1>Jogar</h1>
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
