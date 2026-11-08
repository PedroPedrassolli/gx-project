import { test, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { ApiError, forgetCsrfToken, getSession, request } from "./api.ts";

// fetch falso: cada chamada leva a próxima resposta da fila e fica gravada.
type Call = { url: string; method: string; headers: Record<string, string>; body?: string };
let calls: Call[] = [];
let replies: Response[] = [];

// A chamada número `index` (falha o teste se ela não aconteceu).
function call(index: number): Call {
  const found = calls[index];
  assert.ok(found, `chamada ${index} não aconteceu`);
  return found;
}

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

beforeEach(() => {
  calls = [];
  replies = [];
  forgetCsrfToken();
  globalThis.fetch = async (url, init = {}) => {
    calls.push({
      url: String(url),
      method: init.method ?? "GET",
      headers: (init.headers ?? {}) as Record<string, string>,
      body: init.body as string | undefined,
    });
    const reply = replies.shift();
    if (!reply) throw new Error("resposta não esperada");
    return reply;
  };
});

const session = { user: null, csrf_token: "token-1" };

test("GET não pede o token CSRF", async () => {
  replies.push(json(200, { data: [1, 2] }));

  assert.deepEqual(await request("GET", "/api/packs"), { data: [1, 2] });
  assert.equal(calls.length, 1);
  assert.equal(call(0).headers["X-CSRF-Token"], undefined);
});

test("pedido que muda algo busca o token antes e manda no cabeçalho, em JSON", async () => {
  replies.push(json(200, session), json(201, { user: { id: 1 } }));

  await request("POST", "/api/session", { email: "a@b.c", password: "x" });

  assert.deepEqual(
    calls.map((call) => `${call.method} ${call.url}`),
    ["GET /api/session", "POST /api/session"],
  );
  assert.equal(call(1).headers["X-CSRF-Token"], "token-1");
  assert.equal(call(1).headers["Content-Type"], "application/json");
  assert.equal(call(1).body, '{"email":"a@b.c","password":"x"}');
});

test("reaproveita o token que veio de getSession", async () => {
  replies.push(json(200, session), new Response(null, { status: 204 }));

  await getSession();
  assert.equal(await request("DELETE", "/api/session"), undefined);
  assert.equal(call(1).headers["X-CSRF-Token"], "token-1");
});

test("página velha (403): busca um token novo e tenta uma vez de novo", async () => {
  replies.push(
    json(200, session),
    json(403, { error: { status: 403, message: "velha" } }),
    json(200, { ...session, csrf_token: "token-2" }),
    new Response(null, { status: 202 }),
  );

  await request("POST", "/api/email_verification");

  assert.equal(calls.length, 4);
  assert.equal(call(3).headers["X-CSRF-Token"], "token-2");
});

test("erro da API vira ApiError com a mensagem e os campos", async () => {
  replies.push(
    json(200, session),
    json(422, {
      error: { status: 422, message: "Confira os campos.", fields: { email: ["não é válido"] } },
    }),
  );

  await assert.rejects(request("POST", "/api/registrations", {}), (error: ApiError) => {
    assert.equal(error.status, 422);
    assert.equal(error.message, "Confira os campos.");
    assert.deepEqual(error.fields, { email: ["não é válido"] });
    return true;
  });
});

test("erro sem JSON vira mensagem genérica", async () => {
  replies.push(new Response("<html>", { status: 500 }));

  await assert.rejects(request("GET", "/api/cards"), {
    message: "Algo deu errado. Tente de novo em instantes.",
  });
});
