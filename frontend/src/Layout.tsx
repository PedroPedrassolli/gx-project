import { Link, Outlet } from "react-router";
import { useLogOut, useSession } from "./account/session.ts";

// Barra do topo, igual em todas as páginas: o nome do site, as cartas e a conta.
export function Layout() {
  const user = useSession().data?.user;
  const logOut = useLogOut();

  return (
    <>
      <nav className="topbar" aria-label="Principal">
        <Link to="/" className="brand">
          GX Project
        </Link>
        <Link to="/cartas">Cartas</Link>
        <span className="account">
          {user && (
            <>
              <span>Olá, {user.nickname}</span>
              <button type="button" className="link-button" onClick={() => logOut.mutate()}>
                Sair
              </button>
            </>
          )}
        </span>
      </nav>
      <Outlet />
    </>
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
