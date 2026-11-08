import { Suspense, useState, type MouseEvent } from "react";
import { useMutation } from "@tanstack/react-query";
import { Link, Outlet, useLocation } from "react-router";
import { request, type User } from "./api.ts";
import { useLogOut, useSession } from "./account/session.ts";
import { SOURCE_URL } from "./legal/LegalPages.tsx";
import { markNavigation, usePageTitle } from "./pageTitle.ts";

// Moldura de todas as páginas: a barra do topo (o nome do site, as cartas e a conta) e o
// rodapé.
export function Layout() {
  const session = useSession();
  const logOut = useLogOut();
  const user = session.data?.user;
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
          GX Project
        </Link>
        <Link to="/cartas">Cartas</Link>
        {user && <Link to="/colecao">Coleção</Link>}
        {user && <Link to="/decks">Decks</Link>}
        <span className="account">
          {user && (
            <>
              <span>
                Olá, <Link to="/conta">{user.nickname}</Link>
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
      <Suspense fallback={<Loading />}>
        <Outlet />
      </Suspense>
      <SiteFooter />
    </>
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

// Teclado: pula a barra do topo e vai direto ao conteúdo da página.
function skipToContent(event: MouseEvent<HTMLAnchorElement>) {
  event.preventDefault();
  const main = document.querySelector<HTMLElement>("main");
  if (main) {
    main.tabIndex = -1;
    main.focus();
  }
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
      Confirme seu e-mail: mandamos um link para <strong>{user.email}</strong>.{" "}
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
