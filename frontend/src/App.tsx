import type { ReactNode } from "react";
import { Link } from "react-router";
import { currentPhase, PHASES } from "./roadmap.ts";
import { usePageTitle } from "./pageTitle.ts";

// Página inicial: a mesa. Os atalhos têm a forma de uma carta, cada um com a cor de
// moldura de um tipo de carta, e o andamento do projeto aparece como as fases de um turno.
// Nada aqui depende da sessão: as seis cartas aparecem para todos (sem conta, as que pedem
// login mandam entrar), e "Entrar" e "Criar conta" ficam no topo. Assim a página não pula
// quando a sessão chega, e as linhas de cartas ficam sempre cheias: 2 ou 3 por linha.
export function App() {
  usePageTitle();
  const phase = currentPhase(PHASES);

  return (
    <main className="page home">
      <header>
        <h1>GX Project</h1>
        <p className="lead">
          Monte seu deck com as cartas da era GX e duele online com os amigos ou contra os
          personagens do anime.
        </p>
      </header>

      <ul className="table-menu" aria-label="Atalhos">
        <MenuCard title="Duelo" to="/salas" frame="effect" art={<DuelArt />}>
          Crie uma sala e mande o código para um amigo duelar com você.
        </MenuCard>
        <MenuCard title="Personagens" to="/personagens" frame="synchro" art={<CharactersArt />}>
          Duele contra o computador com os decks dos personagens do anime.
        </MenuCard>
        <MenuCard title="Decks" to="/decks" frame="spell" art={<DeckArt />}>
          Monte, confira e importe os seus decks.
        </MenuCard>
        <MenuCard title="Loja" to="/loja" frame="ritual" art={<ShopArt />}>
          Gaste o DP dos duelos em pacotes e troque as repetidas.
        </MenuCard>
        <MenuCard title="Desafios" to="/desafios" frame="trap" art={<ChallengesArt />}>
          Missões que liberam pacotes e os 104 desafios do jogo.
        </MenuCard>
        <MenuCard title="Coleção" to="/colecao" frame="fusion" art={<CollectionArt />}>
          Quanto você já tem de cada pacote.
        </MenuCard>
      </ul>

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
    </main>
  );
}

// Um atalho em forma de carta: nome em cima, ilustração no meio e o texto embaixo. Sem
// "to", é algo que ainda não existe (aparece apagado, com "Em breve" no texto).
function MenuCard(props: {
  title: string;
  to?: string;
  frame: string;
  art: ReactNode;
  children: ReactNode;
}) {
  return (
    <li className={`menu-card frame-${props.frame}${props.to ? "" : " soon"}`}>
      <h2>{props.to ? <Link to={props.to}>{props.title}</Link> : props.title}</h2>
      <div className="menu-art">{props.art}</div>
      <p>{props.children}</p>
    </li>
  );
}

// Ilustrações dos atalhos: traços simples, desenho próprio.
function Art({ children }: { children: ReactNode }) {
  return (
    <svg viewBox="0 0 48 48" aria-hidden="true">
      {children}
    </svg>
  );
}

const DuelArt = () => (
  <Art>
    <rect x="9" y="10" width="15" height="22" rx="2" transform="rotate(-18 16 21)" />
    <rect x="24" y="10" width="15" height="22" rx="2" transform="rotate(18 31 21)" />
    <path d="M17 40h14" />
  </Art>
);

const DeckArt = () => (
  <Art>
    <rect x="13" y="14" width="18" height="26" rx="2" />
    <path d="M17 10h18v26M21 6h18v26" />
  </Art>
);

// Um duelista: a cabeça, os ombros e uma carta na mão.
const CharactersArt = () => (
  <Art>
    <circle cx="20" cy="15" r="6" />
    <path d="M8 40c0-8 5-13 12-13s12 5 12 13" />
    <rect x="30" y="16" width="10" height="15" rx="1.5" transform="rotate(12 35 23)" />
  </Art>
);

// Um pacote de cartas fechado, com a aba de abrir em cima.
const ShopArt = () => (
  <Art>
    <path d="M13 9h22l-2 4 2 4v24H13V17l2-4z" />
    <path d="M13 17h22M19 27h10M24 22v10" />
  </Art>
);

// Uma medalha pendurada na fita.
const ChallengesArt = () => (
  <Art>
    <path d="m16 6 8 14 8-14" />
    <circle cx="24" cy="30" r="10" />
    <path d="m24 25 1.6 3.3 3.6.5-2.6 2.5.6 3.6-3.2-1.7-3.2 1.7.6-3.6-2.6-2.5 3.6-.5z" />
  </Art>
);

const CollectionArt = () => (
  <Art>
    <rect x="8" y="7" width="14" height="16" rx="2" />
    <rect x="26" y="7" width="14" height="16" rx="2" />
    <rect x="8" y="27" width="14" height="16" rx="2" />
    <rect x="26" y="27" width="14" height="16" rx="2" />
  </Art>
);
