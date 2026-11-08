import { useId, useState, type FormEvent } from "react";
import { Link } from "react-router";
import { ApiError } from "../api.ts";
import { useSignUp } from "./session.ts";
import { sentence, TextField } from "./TextField.tsx";

const EMPTY = { email: "", password: "", nickname: "", birth_date: "" };

// Cadastro (escopo 3.1): a data de nascimento só serve para a faixa de idade.
export function SignUpPage() {
  const signUp = useSignUp();
  const [form, setForm] = useState(EMPTY);
  const [accepted, setAccepted] = useState(false);
  const fields = signUp.error instanceof ApiError ? signUp.error.fields : {};
  const change = (name: keyof typeof EMPTY) => (value: string) =>
    setForm({ ...form, [name]: value });

  function submit(event: FormEvent) {
    event.preventDefault();
    signUp.mutate({ ...form, terms_accepted: accepted });
  }

  if (signUp.isSuccess) {
    return (
      <main className="page narrow">
        <h1>Conta criada!</h1>
        <p role="status">
          Mandamos um link para <strong>{form.email}</strong>. Abra para confirmar seu e-mail.
        </p>
        <p>
          <Link className="cta" to="/cartas">
            Ver o catálogo de cartas
          </Link>
        </p>
      </main>
    );
  }

  return (
    <main className="page narrow">
      <h1>Criar conta</h1>
      <form className="form" onSubmit={submit} noValidate>
        <TextField
          label="E-mail"
          type="email"
          autoComplete="email"
          value={form.email}
          onChange={change("email")}
          errors={fields.email}
        />
        <TextField
          label="Senha"
          type="password"
          autoComplete="new-password"
          hint="8 caracteres ou mais."
          value={form.password}
          onChange={change("password")}
          errors={fields.password}
        />
        <TextField
          label="Apelido"
          autoComplete="username"
          hint="De 3 a 20 caracteres: letras sem acento, números, _ e -. É o nome que os outros veem."
          value={form.nickname}
          onChange={change("nickname")}
          errors={fields.nickname}
        />
        <TextField
          label="Data de nascimento"
          type="date"
          autoComplete="bday"
          hint="Para saber se você tem 13 anos ou mais. Guardamos só a faixa de idade, não a data."
          value={form.birth_date}
          onChange={change("birth_date")}
          errors={fields.birth_date}
        />
        <TermsCheckbox checked={accepted} onChange={setAccepted} errors={fields.terms} />
        {signUp.error && (
          <p role="alert" className="form-error">
            {signUp.error instanceof ApiError
              ? signUp.error.message
              : "Sem conexão. Tente de novo."}
          </p>
        )}
        <button type="submit" className="cta" disabled={signUp.isPending}>
          {signUp.isPending ? "Criando…" : "Criar conta"}
        </button>
      </form>
      <p>
        Já tem conta? <Link to="/entrar">Entrar</Link>
      </p>
    </main>
  );
}

type TermsProps = {
  checked: boolean;
  onChange: (checked: boolean) => void;
  errors?: string[];
};

// Aceite dos textos legais (GXP-40). Os links abrem em outra aba para o formulário não se
// perder.
function TermsCheckbox({ checked, onChange, errors = [] }: TermsProps) {
  const errorId = useId();
  const invalid = errors.length > 0;

  return (
    <div className="form-field">
      <label className="checkbox">
        <input
          type="checkbox"
          checked={checked}
          required
          aria-invalid={invalid || undefined}
          aria-describedby={invalid ? errorId : undefined}
          onChange={(event) => onChange(event.target.checked)}
        />
        <span>
          Li e aceito os{" "}
          <Link to="/termos" target="_blank">
            Termos de uso
          </Link>{" "}
          e a{" "}
          <Link to="/privacidade" target="_blank">
            Política de privacidade
          </Link>
          .
        </span>
      </label>
      {invalid && (
        <p id={errorId} className="field-error">
          {errors.map(sentence).join(" ")}
        </p>
      )}
    </div>
  );
}
