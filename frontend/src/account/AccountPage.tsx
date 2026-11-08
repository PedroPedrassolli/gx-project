import { useState, type FormEvent } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Link } from "react-router";
import { ApiError, request } from "../api.ts";
import { useSession } from "./session.ts";
import { TextField } from "./TextField.tsx";

const AGE_GROUPS = { "13-17": "13 a 17 anos", "18+": "18 anos ou mais" };

// Minha conta (escopo 3.1): os dados da conta e os direitos da LGPD, baixar tudo o que
// guardamos e excluir a conta (GXP-36).
export function AccountPage() {
  const session = useSession();
  const user = session.data?.user;
  const client = useQueryClient();
  const [password, setPassword] = useState("");
  const [confirming, setConfirming] = useState(false);
  const destroy = useMutation({
    mutationFn: () => request("DELETE", "/api/me", { password }),
    onSuccess: () => client.invalidateQueries(),
  });
  const fields = destroy.error instanceof ApiError ? destroy.error.fields : {};

  function submit(event: FormEvent) {
    event.preventDefault();
    if (confirming) destroy.mutate();
    else setConfirming(true);
  }

  if (destroy.isSuccess) {
    return (
      <main className="page narrow">
        <h1>Conta excluída</h1>
        <p role="status">Apagamos sua conta, sua coleção e seus decks.</p>
        <p>
          <Link to="/">Voltar para o começo</Link>
        </p>
      </main>
    );
  }
  if (session.isSuccess && !user) {
    return (
      <main className="page narrow">
        <h1>Minha conta</h1>
        <p>
          <Link to="/entrar">Entre na sua conta</Link> para ver seus dados.
        </p>
      </main>
    );
  }
  if (!user) return null;

  return (
    <main className="page narrow">
      <h1>Minha conta</h1>
      <dl className="account-data">
        <dt>E-mail</dt>
        <dd>
          {user.email} ({user.email_verified ? "confirmado" : "ainda não confirmado"})
        </dd>
        <dt>Apelido</dt>
        <dd>{user.nickname}</dd>
        <dt>Faixa de idade</dt>
        <dd>{AGE_GROUPS[user.age_group]}</dd>
      </dl>

      <h2>Seus dados</h2>
      <p>Baixe tudo o que guardamos sobre você: conta, coleção e decks, num arquivo JSON.</p>
      <p>
        <a className="cta" href="/api/me/export" download>
          Baixar meus dados
        </a>
      </p>

      <h2>Excluir conta</h2>
      <p>Apaga a conta, a coleção e os decks na hora. Não dá para desfazer.</p>
      <form className="form" onSubmit={submit} noValidate>
        <TextField
          label="Senha"
          type="password"
          autoComplete="current-password"
          hint="Para confirmar que é você."
          value={password}
          onChange={setPassword}
          errors={fields.password}
        />
        {destroy.error && !fields.password && (
          <p role="alert" className="form-error">
            {destroy.error instanceof ApiError
              ? destroy.error.message
              : "Sem conexão. Tente de novo."}
          </p>
        )}
        <button type="submit" className="danger" disabled={destroy.isPending || password === ""}>
          {confirming ? "Confirmar: excluir minha conta" : "Excluir minha conta"}
        </button>
      </form>
    </main>
  );
}
