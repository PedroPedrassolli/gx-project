import { useEffect } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Link, useSearchParams } from "react-router";
import { ApiError, request } from "../api.ts";

// Confirmação do e-mail pelo link (/verificar-email?token=...): confirma assim que abre.
export function VerifyEmailPage() {
  const [params] = useSearchParams();
  const client = useQueryClient();
  const confirm = useMutation({
    mutationFn: (token: string) => request("PATCH", "/api/email_verification", { token }),
    onSuccess: () => client.invalidateQueries({ queryKey: ["session"] }),
  });
  const token = params.get("token") ?? "";
  const { mutate } = confirm;

  useEffect(() => mutate(token), [mutate, token]);

  return (
    <main className="page narrow">
      <h1>Confirmar e-mail</h1>
      {confirm.isPending && <p role="status">Confirmando…</p>}
      {confirm.isSuccess && (
        <>
          <p role="status">E-mail confirmado. Obrigado!</p>
          <p>
            <Link className="cta" to="/cartas">
              Ver o catálogo de cartas
            </Link>
          </p>
        </>
      )}
      {confirm.error && (
        <p role="alert" className="form-error">
          {confirm.error instanceof ApiError
            ? confirm.error.message
            : "Sem conexão. Tente de novo."}
        </p>
      )}
    </main>
  );
}
