import { useState, type FormEvent } from "react";
import { useMutation } from "@tanstack/react-query";
import { Link, useSearchParams } from "react-router";
import { ApiError, request } from "../api.ts";
import { TextField } from "./TextField.tsx";

function errorMessage(error: Error) {
  return error instanceof ApiError ? error.message : "Sem conexão. Tente de novo.";
}

// Esqueci a senha: a resposta é a mesma com ou sem conta, como a da API.
export function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const ask = useMutation({ mutationFn: () => request("POST", "/api/password", { email }) });

  function submit(event: FormEvent) {
    event.preventDefault();
    ask.mutate();
  }

  return (
    <main className="page narrow">
      <h1>Esqueci a senha</h1>
      {ask.isSuccess ? (
        <p role="status">
          Se <strong>{email}</strong> tiver conta, mandamos um link para criar uma senha nova. Ele
          vale por 1 hora.
        </p>
      ) : (
        <form className="form" onSubmit={submit} noValidate>
          <TextField
            label="E-mail"
            type="email"
            autoComplete="email"
            value={email}
            onChange={setEmail}
          />
          {ask.error && (
            <p role="alert" className="form-error">
              {errorMessage(ask.error)}
            </p>
          )}
          <button type="submit" className="cta" disabled={ask.isPending}>
            Mandar o link
          </button>
        </form>
      )}
    </main>
  );
}

// Senha nova, pelo link do e-mail (/nova-senha?token=...).
export function NewPasswordPage() {
  const [params] = useSearchParams();
  const [password, setPassword] = useState("");
  const reset = useMutation({
    mutationFn: () =>
      request("PATCH", "/api/password", { token: params.get("token") ?? "", password }),
  });
  const fields = reset.error instanceof ApiError ? reset.error.fields : {};

  function submit(event: FormEvent) {
    event.preventDefault();
    reset.mutate();
  }

  if (reset.isSuccess) {
    return (
      <main className="page narrow">
        <h1>Senha trocada!</h1>
        <p role="status">Por segurança, saímos da sua conta em todos os aparelhos.</p>
        <p>
          <Link className="cta" to="/entrar">
            Entrar
          </Link>
        </p>
      </main>
    );
  }

  return (
    <main className="page narrow">
      <h1>Criar senha nova</h1>
      <form className="form" onSubmit={submit} noValidate>
        <TextField
          label="Senha nova"
          type="password"
          autoComplete="new-password"
          hint="8 caracteres ou mais."
          value={password}
          onChange={setPassword}
          errors={fields.password}
        />
        {reset.error && (
          <p role="alert" className="form-error">
            {errorMessage(reset.error)}{" "}
            {!fields.password && <Link to="/esqueci-a-senha">Pedir outro link</Link>}
          </p>
        )}
        <button type="submit" className="cta" disabled={reset.isPending}>
          Trocar a senha
        </button>
      </form>
    </main>
  );
}
