// Cliente da API (ADR 0007 e 0008): JSON no mesmo domínio, com o cookie de login. Todo
// pedido que muda algo leva o token CSRF no cabeçalho; se a página ficou velha (403),
// busca um token novo e tenta mais uma vez.

export type User = {
  id: number;
  email: string;
  email_verified: boolean;
  nickname: string;
  age_group: "13-17" | "18+";
  role: string;
};

export type Session = { user: User | null; csrf_token: string };

// Erro da API: a mensagem para mostrar e, em formulário, as mensagens de cada campo.
export class ApiError extends Error {
  status: number;
  fields: Record<string, string[]>;

  constructor(status: number, message: string, fields: Record<string, string[]> = {}) {
    super(message);
    this.status = status;
    this.fields = fields;
  }
}

const GENERIC_ERROR = "Algo deu errado. Tente de novo em instantes.";

// Pedido que passa disso desiste, e a tela mostra o erro em vez de esperar para sempre. O
// Rails na Vercel leva uns 5 s para acordar, e mandar um e-mail, mais alguns.
export const TIMEOUT_MS = 30_000;

let csrfToken: string | null = null;

export function forgetCsrfToken() {
  csrfToken = null;
}

// Quem está logado (ou null) e o token CSRF, que fica guardado para os próximos pedidos.
export async function getSession(): Promise<Session> {
  const session = await request<Session>("GET", "/api/session");
  csrfToken = session.csrf_token;
  return session;
}

export async function request<T>(
  method: string,
  path: string,
  body?: unknown,
  retry = true,
): Promise<T> {
  const headers: Record<string, string> = { Accept: "application/json" };
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (method !== "GET") {
    if (!csrfToken) await getSession();
    headers["X-CSRF-Token"] = csrfToken ?? "";
  }

  const response = await fetch(path, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });

  if (response.status === 403 && method !== "GET" && retry) {
    forgetCsrfToken();
    return request<T>(method, path, body, false);
  }

  const text = await response.text();
  const data = text ? parse(text) : undefined;
  if (!response.ok) {
    const error = data?.error;
    throw new ApiError(response.status, error?.message ?? GENERIC_ERROR, error?.fields ?? {});
  }
  return data as T;
}

function parse(text: string) {
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}
