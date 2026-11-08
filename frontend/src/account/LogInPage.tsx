import { useState, type FormEvent } from "react";
import { Link, useNavigate } from "react-router";
import { ApiError } from "../api.ts";
import { useLogIn } from "./session.ts";
import { TextField } from "./TextField.tsx";

export function LogInPage() {
  const logIn = useLogIn();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  function submit(event: FormEvent) {
    event.preventDefault();
    logIn.mutate({ email, password }, { onSuccess: () => navigate("/") });
  }

  return (
    <main className="page narrow">
      <h1>Entrar</h1>
      <form className="form" onSubmit={submit} noValidate>
        <TextField
          label="E-mail"
          type="email"
          autoComplete="email"
          value={email}
          onChange={setEmail}
        />
        <TextField
          label="Senha"
          type="password"
          autoComplete="current-password"
          value={password}
          onChange={setPassword}
        />
        {logIn.error && (
          <p role="alert" className="form-error">
            {logIn.error instanceof ApiError ? logIn.error.message : "Sem conexão. Tente de novo."}
          </p>
        )}
        <button type="submit" className="cta" disabled={logIn.isPending}>
          {logIn.isPending ? "Entrando…" : "Entrar"}
        </button>
      </form>
      <p>
        <Link to="/esqueci-a-senha">Esqueci a senha</Link>
      </p>
    </main>
  );
}
