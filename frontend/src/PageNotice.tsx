import type { ReactNode } from "react";
import { Link } from "react-router";

// Página curta, só com o título e um aviso: carregando, não encontrado, entrar na conta.
export function PageNotice({ title, children }: { title: string; children: ReactNode }) {
  return (
    <main className="page narrow">
      <h1>{title}</h1>
      {children}
    </main>
  );
}

// A página precisa da conta: o convite para entrar, com o motivo ("para jogar").
export function SignInFirst({ title, reason }: { title: string; reason: string }) {
  return (
    <PageNotice title={title}>
      <p>
        <Link to="/entrar">Entre na sua conta</Link> {reason}.
      </p>
    </PageNotice>
  );
}
