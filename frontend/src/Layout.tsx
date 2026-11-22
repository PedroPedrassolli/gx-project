import {
  Suspense,
  useLayoutEffect,
  useRef,
  useState,
  type MouseEvent,
  type ReactNode,
} from "react";
import { useMutation } from "@tanstack/react-query";
import { Link, Outlet, useLocation } from "react-router";
import { request, type User } from "./api.ts";
import { useSession } from "./account/session.ts";
import { SPAM_HINT } from "./account/spamHint.ts";
import { markNavigation, usePageTitle } from "./pageTitle.ts";

// Moldura de todas as páginas (ADR 0015): a barra do topo (a marca, o menu e a conta), os
// avisos (e-mail por confirmar, duelo em andamento) e o rodapé. No celular, o menu vira a
// barra de abas fixa embaixo, perto do polegar; na mesa do duelo ela some.
export function Layout() {
  const session = useSession();
  const user = session.data?.user;
  // Enquanto a sessão não chega, o menu já é o de quem tem conta (a maioria): sem conta, ele
  // troca quando a resposta chega.
  const visitor = session.isSuccess && !user;
  // Fechou a aba ou o celular apagou no meio do duelo: de qualquer página, um toque volta
  // para a mesa (o prazo da resposta continua correndo no servidor).
  const duel = user ? session.data?.duel : null;
  const { pathname } = useLocation();
  const [firstPath] = useState(pathname);
  // Na mesa do duelo, nada além da barra do topo: a mesa ocupa o resto da tela (GXP-99).
  const inDuel = /^\/duelo\/\d+$/.test(pathname);
  const topbar = useHeaderHeight();
  // Avisa antes de a página nova montar: é ela que leva o foco para o próprio título.
  if (pathname !== firstPath) markNavigation();

  return (
    <div className={inDuel ? "shell in-duel" : "shell"}>
      <a className="skip-link" href="#conteudo" onClick={skipToContent}>
        Pular para o conteúdo
      </a>
      <header className="topbar" ref={topbar}>
        <Link to="/" className="brand">
          <BrandMark />
          <span className="brand-name">GX Project</span>
        </Link>
        <nav className="mainnav" aria-label="Principal">
          {(visitor ? VISITOR_MENU : PLAYER_MENU).map((item) => (
            <Link
              key={item.to}
              to={item.to}
              aria-current={item.match.test(pathname) ? "page" : undefined}
            >
              {item.icon}
              <span>{item.label}</span>
            </Link>
          ))}
        </nav>
        {user && (
          <div className="account">
            <span className="wallet-chip">{user.dp.toLocaleString("pt-BR")} DP</span>
            <span className="level-chip">Nível {user.level}</span>
            <Link to="/conta" className="avatar-link">
              <span className="avatar-initial" aria-hidden="true">
                {user.nickname.charAt(0).toUpperCase()}
              </span>
              <span className="nickname">{user.nickname}</span>
            </Link>
          </div>
        )}
      </header>
      {user && !user.email_verified && !inDuel && <ConfirmEmailNotice user={user} />}
      {duel && pathname !== `/duelo/${duel.match_id}` && (
        <p className="notice" role="status">
          Você tem um duelo em andamento.{" "}
          <Link to={`/duelo/${duel.match_id}`}>Voltar para a mesa</Link>
        </p>
      )}
      <div id="conteudo" tabIndex={-1}>
        <Suspense fallback={<Loading />}>
          <Outlet />
        </Suspense>
      </div>
      {!inDuel && <SiteFooter />}
    </div>
  );
}

type MenuItem = { to: string; label: string; icon: ReactNode; match: RegExp };

// Ícones do menu: traços simples, desenho próprio.
function Icon({ children }: { children: ReactNode }) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      {children}
    </svg>
  );
}

const HOME_ITEM: MenuItem = {
  to: "/",
  label: "Início",
  match: /^\/$/,
  icon: (
    <Icon>
      <path d="M3 10.5 12 3l9 7.5V21h-6v-6H9v6H3z" />
    </Icon>
  ),
};

// Com conta, as cinco áreas do jogo. "Jogar" junta personagens, salas e a mesa; a coleção
// inclui o catálogo de todas as cartas.
const PLAYER_MENU: MenuItem[] = [
  HOME_ITEM,
  {
    to: "/jogar",
    label: "Jogar",
    match: /^\/(jogar|personagens|salas|duelo)/,
    icon: (
      <Icon>
        <rect x="2.5" y="5" width="9" height="13" rx="1.5" transform="rotate(-12 7 11.5)" />
        <rect x="12.5" y="5" width="9" height="13" rx="1.5" transform="rotate(12 17 11.5)" />
      </Icon>
    ),
  },
  {
    to: "/decks",
    label: "Decks",
    match: /^\/decks/,
    icon: (
      <Icon>
        <rect x="8" y="3" width="11" height="15" rx="1.5" />
        <path d="M5 7v12.5A1.5 1.5 0 0 0 6.5 21H15" />
      </Icon>
    ),
  },
  {
    to: "/colecao",
    label: "Coleção",
    match: /^\/(colecao|cartas)/,
    icon: (
      <Icon>
        <rect x="3" y="3" width="18" height="18" rx="2" />
        <path d="M9 3v18M15 3v18M3 9h18M3 15h18" />
      </Icon>
    ),
  },
  {
    to: "/loja",
    label: "Loja",
    match: /^\/loja/,
    icon: (
      <Icon>
        <path d="M6 3h12l1 4H5z" />
        <path d="M5 7h14v14H5z" />
        <path d="M9.5 12h5" />
      </Icon>
    ),
  },
];

// Sem conta: o começo, o catálogo, entrar e criar conta.
const VISITOR_MENU: MenuItem[] = [
  HOME_ITEM,
  {
    to: "/cartas",
    label: "Cartas",
    match: /^\/cartas/,
    icon: (
      <Icon>
        <rect x="5" y="3" width="14" height="18" rx="2" />
        <path d="M8 7h8M8 17h5" />
      </Icon>
    ),
  },
  {
    to: "/entrar",
    label: "Entrar",
    match: /^\/entrar/,
    icon: (
      <Icon>
        <path d="M14 4h5v16h-5" />
        <path d="M3 12h11M10 8l4 4-4 4" />
      </Icon>
    ),
  },
  {
    to: "/cadastro",
    label: "Criar conta",
    match: /^\/cadastro/,
    icon: (
      <Icon>
        <circle cx="10" cy="8" r="4" />
        <path d="M3 21c0-4 3-7 7-7s7 3 7 7M19 8v6M16 11h6" />
      </Icon>
    ),
  },
];

// A altura da barra do topo em --header-h, para a mesa do duelo saber quanto sobra da tela
// (a barra tem duas linhas no celular e uma no computador).
function useHeaderHeight() {
  const ref = useRef<HTMLElement>(null);
  useLayoutEffect(() => {
    const element = ref.current;
    if (!element) return;
    const root = document.documentElement;
    const update = () => root.style.setProperty("--header-h", `${element.offsetHeight}px`);
    update();
    const observer = new ResizeObserver(update);
    observer.observe(element);
    return () => observer.disconnect();
  }, []);
  return ref;
}

// A marca do site: três cartas em leque, nas cores dos três dormitórios (desenho próprio).
function BrandMark() {
  return (
    <svg className="brand-mark" viewBox="0 0 34 28" aria-hidden="true">
      <rect
        className="red"
        x="10"
        y="3"
        width="14"
        height="20"
        rx="2"
        transform="rotate(-20 17 25)"
      />
      <rect className="yellow" x="10" y="3" width="14" height="20" rx="2" />
      <rect
        className="blue"
        x="10"
        y="3"
        width="14"
        height="20"
        rx="2"
        transform="rotate(20 17 25)"
      />
    </svg>
  );
}

// Cada página é um arquivo JS baixado na primeira visita (main.tsx): enquanto chega, isto.
function Loading() {
  return (
    <main className="page">
      <p role="status">Carregando…</p>
    </main>
  );
}

// Teclado: pula a barra do topo e vai direto ao conteúdo da página (sem pôr #conteudo
// no endereço).
function skipToContent(event: MouseEvent<HTMLAnchorElement>) {
  event.preventDefault();
  document.getElementById("conteudo")?.focus();
}

// Aviso de fã, créditos, textos legais e o código-fonte (escopo, telas: "Legais").
function SiteFooter() {
  return (
    <footer className="site-footer">
      <p>
        Projeto de fã, sem fins lucrativos. Yu-Gi-Oh! é marca registrada da Konami; este projeto não
        tem ligação com a Konami nem é aprovado por ela. Dados das cartas da{" "}
        <a href="https://yugipedia.com">Yugipedia</a> (
        <a href="https://creativecommons.org/licenses/by-sa/4.0/deed.pt-br">CC BY-SA</a>) e imagens
        do <a href="https://ygoprodeck.com">YGOPRODeck</a>.
      </p>
      <ul className="footer-links">
        <li>
          <Link to="/termos">Termos de uso</Link>
        </li>
        <li>
          <Link to="/privacidade">Privacidade</Link>
        </li>
      </ul>
    </footer>
  );
}

// Aviso para quem ainda não confirmou o e-mail, com o botão para mandar o link de novo.
function ConfirmEmailNotice({ user }: { user: User }) {
  const resend = useMutation({ mutationFn: () => request("POST", "/api/email_verification") });

  return (
    <p className="notice" role="status">
      Confirme seu e-mail: mandamos um link para <strong>{user.email}</strong>. {SPAM_HINT}{" "}
      {resend.isSuccess ? (
        "Mandamos de novo."
      ) : (
        <button
          type="button"
          className="link-button"
          disabled={resend.isPending}
          onClick={() => resend.mutate()}
        >
          Mandar de novo
        </button>
      )}
      {resend.error && " Não deu para mandar agora; tente daqui a pouco."}
    </p>
  );
}

export function NotFound() {
  usePageTitle("Página não encontrada");
  return (
    <main className="page narrow">
      <h1>Página não encontrada</h1>
      <p>
        <Link to="/">Voltar para o começo</Link>
      </p>
    </main>
  );
}
