import { useMutation } from "@tanstack/react-query";
import { Link, Outlet } from "react-router";
import { request, type User } from "./api.ts";
import { useLogOut, useSession } from "./account/session.ts";

// Barra do topo, igual em todas as páginas: o nome do site, as cartas e a conta.
export function Layout() {
  const session = useSession();
  const logOut = useLogOut();
  const user = session.data?.user;

  return (
    <>
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
              <button type="button" className="link-button" onClick={() => logOut.mutate()}>
                Sair
              </button>
            </>
          )}
          {session.isSuccess && !user && <Link to="/entrar">Entrar</Link>}
        </span>
      </nav>
      {user && !user.email_verified && <ConfirmEmailNotice user={user} />}
      <Outlet />
    </>
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
  return (
    <main className="page narrow">
      <h1>Página não encontrada</h1>
      <p>
        <Link to="/">Voltar para o começo</Link>
      </p>
    </main>
  );
}
