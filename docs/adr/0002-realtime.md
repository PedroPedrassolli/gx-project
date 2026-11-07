# ADR 0002: tempo real (Ably)

- **Data:** 07/11/2026
- **Situação:** aceita (GXP-5). O teste ao vivo espera a chave do Ably.

## Contexto

O servidor é a autoridade do duelo e precisa avisar cada jogador do que mudou. O Rails roda
num container da Vercel, sem worker e sem conexão aberta com o navegador. O escopo (seção
5.5) pede um canal por jogador, `private:user:{id}`, com um token emitido pelo Rails que só
permite assinar esse canal, e escolheu o Ably (decisão 3).

## Decisão

1. **Ably no plano Free**, sem cartão. Não existe cobrança por excedente: passou do limite,
   o Ably recusa, e o front cai para consultar o servidor a cada 2 s (escopo, 5.5).
2. **Publicar pelo REST do Ably**, com `Net::HTTP` (`Realtime::AblyPublisher`): um `POST`
   por evento, com a chave em Basic auth. A gem `ably-rest` traria typhoeus e libcurl para a
   imagem por causa de uma chamada HTTP.
3. **Token:** o Rails assina um pedido de token (`Realtime::TokenRequest`, conforme a "REST
   API Token Request Spec" do Ably) com permissão só de `subscribe` em
   `private:user:{id}`, `clientId` igual ao id do jogador e validade de 1 hora. O navegador
   troca o pedido por um token direto no Ably (o `authUrl` do ably-js). A chave nunca vai
   para o navegador.
4. **Sem a chave** (desenvolvimento e CI), os eventos ficam na memória
   (`Realtime::MemoryPublisher`), com o mesmo método `publish(user_id:, event:, data:)`.
   `Realtime::Publisher.current` escolhe pela presença da `ABLY_API_KEY`.
5. **O endpoint `POST /api/realtime/token` entra com as contas (F2).** Sem a sessão do
   jogador, ele emitiria token para qualquer id.

## Consumo do plano grátis

Limites do Free (página de preços do Ably, conferida em 07/11/2026): 6 milhões de mensagens
por mês, 200 conexões e 200 canais ao mesmo tempo, 500 mensagens por segundo.

- Cada evento conta 2 mensagens: a publicada e a entregue a quem assina (cada canal privado
  tem um assinante só).
- O duelo gravado dos bots (`/up/engine`, 20 turnos) tem 403 respostas: 283 são cadeias sem
  opção, que o servidor responde sozinho, e 120 são decisões de jogador. Com uma mensagem por
  jogador por ação, são 120 × 2 jogadores × 2 = **480 mensagens por duelo 1x1** (o dobro no
  Tag, com 4 jogadores).
- 6 milhões ÷ 480 dá uns **12.500 duelos 1x1 por mês** (cerca de 400 por dia). Antes disso
  aparece o limite de **200 conexões**: 200 jogadores conectados ao mesmo tempo, ou 100
  duelos 1x1 simultâneos. Por isso o front só conecta na fila, na sala ou no duelo, e fecha
  depois de 2 minutos com a aba oculta (escopo, 5.5).
- O workflow *Teste do Ably* gasta 3 mensagens por rodada.

## Consequências

- Para ligar: o Pedro cria a conta e o app no Ably (Free), cola a chave em `ABLY_API_KEY` na
  Vercel (Production) e no GitHub (secret) e roda o *Teste do Ably*. Ele confere que o Ably
  aceita o token assinado pelo Rails, que o canal do jogador recebe o evento e que o canal de
  outro jogador é recusado.
- Se o Ably recusar uma publicação (limite, fora do ar), o `AblyPublisher` levanta erro. O
  fluxo da ação (F3) precisa gravar a resposta mesmo assim: o jogador recupera o estado pelo
  `GET /api/matches/:id/state`.

## Alternativas descartadas

- **Action Cable no próprio Rails:** precisa de conexão aberta no servidor, o que não cabe no
  container da Vercel. Fica como plano B, junto com a VM própria (escopo, riscos).
- **Supabase Realtime:** o escopo deixa o Supabase só para o banco (decisão 3).
