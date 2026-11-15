import { Suspense, useState, type MouseEvent } from "react";
import { useMutation } from "@tanstack/react-query";
import { Link, NavLink, Outlet, useLocation } from "react-router";
import { request, type User } from "./api.ts";
import { useLogOut, useSession } from "./account/session.ts";
import { SPAM_HINT } from "./account/spamHint.ts";
import { SOURCE_URL } from "./legal/source.ts";
import { markNavigation, usePageTitle } from "./pageTitle.ts";

// Moldura de todas as páginas: a barra do topo (o nome do site, o menu e a conta), os avisos
// (e-mail por confirmar, duelo em andamento) e o rodapé. No celular, a barra tem duas linhas
// fixas: a marca e a conta em cima, o menu embaixo.
export function Layout() {
  const session = useSession();
  const logOut = useLogOut();
  const user = session.data?.user;
  // Fechou a aba ou o celular apagou no meio do duelo: de qualquer página, um toque volta
  // para a mesa (o prazo da resposta continua correndo no servidor).
  const duel = user ? session.data?.duel : null;
  const { pathname } = useLocation();
  const [firstPath] = useState(pathname);
  // Avisa antes de a página nova montar: é ela que leva o foco para o próprio título.
  if (pathname !== firstPath) markNavigation();

  return (
    <>
      <a className="skip-link" href="#conteudo" onClick={skipToContent}>
        Pular para o conteúdo
      </a>
      <nav className="topbar" aria-label="Principal">
        <Link to="/" className="brand">
          <BrandMark />
          <span className="brand-name">GX Project</span>
        </Link>
        <span className="topbar-links">
          <NavLink to="/cartas">Cartas</NavLink>
          {user && <NavLink to="/colecao">Coleção</NavLink>}
          {user && <NavLink to="/decks">Decks</NavLink>}
          {user && <NavLink to="/salas">Duelo</NavLink>}
          {user && <NavLink to="/loja">Loja</NavLink>}
        </span>
        <span className="account">
          {user && (
            <>
              <span>
                <span className="greeting">Olá, </span>
                <Link to="/conta">{user.nickname}</Link>
              </span>
              <span className="wallet">
                {user.dp.toLocaleString("pt-BR")} DP, nível {user.level}
              </span>
              <button
                type="button"
                className="link-button"
                disabled={logOut.isPending}
                onClick={() => logOut.mutate()}
              >
                Sair
              </button>
            </>
          )}
          {session.isSuccess && !user && (
            <>
              <Link to="/entrar">Entrar</Link>
              <Link to="/cadastro">Criar conta</Link>
            </>
          )}
        </span>
      </nav>
      {user && !user.email_verified && <ConfirmEmailNotice user={user} />}
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
      <SiteFooter />
    </>
  );
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
        <li>
          <a href={SOURCE_URL}>Código-fonte</a> (AGPL-3.0)
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
