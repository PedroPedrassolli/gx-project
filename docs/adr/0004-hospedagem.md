# ADR 0004: hospedagem e planos gratuitos

- **Data:** 07/11/2026
- **Situação:** aceita (GXP-8). O banco, o e-mail e o backup entram na F2; as imagens, na F1.

## Contexto

Regra do projeto: só planos gratuitos, sem cartão, e nunca uma cobrança por excedente
ligada. O escopo (5.9) lista os serviços e pede para validar os limites e medir o consumo
ainda na F0. Este ADR registra os limites conferidos, quanto o jogo gasta de cada um e as
escolhas que saíram disso.

## Limites conferidos em 07/11/2026

| Serviço e plano | Para quê | Limites que importam (por mês) | Se passar | Fonte |
| --- | --- | --- | --- | --- |
| Vercel Hobby | Front e API (container) | 1 milhão de invocações; 4 h de CPU ativa; 360 GB-h de memória; 1 milhão de requisições na CDN; 100 GB de *Fast Data Transfer*; 10 GB de *Fast Origin Transfer*; funções numa região só; uso pessoal e não comercial | Não cobra. O recurso fica parado até completar 30 dias | [Hobby](https://vercel.com/docs/plans/hobby), [regiões](https://vercel.com/docs/functions/configuring-functions/region) |
| Vercel Blob (Hobby) | Backup | 1 GB guardado; 10 mil operações simples; 2 mil avançadas (upload, cópia, listagem); 10 GB de transferência | Não cobra. O Blob fica fora por 30 dias | [Blob](https://vercel.com/docs/vercel-blob/usage-and-pricing) |
| Supabase Free | Postgres | 500 MB de banco; 5 GB de saída, contando o que o banco manda para o Rails pelo pooler; 2 projetos ativos; pausa depois de 1 semana sem uso; sem backup | Não cobra. Aviso, um prazo de tolerância e depois restrição do projeto | [preços](https://supabase.com/pricing), [saída](https://supabase.com/docs/guides/platform/manage-your-usage/egress), [FAQ](https://supabase.com/docs/guides/platform/billing-faq) |
| Ably Free | Tempo real | 6 milhões de mensagens; 200 conexões e 200 canais ao mesmo tempo; 500 mensagens por segundo; 64 KiB por mensagem | Recusa | [preços](https://ably.com/pricing) |
| Cloudflare Pages (Free) | Imagens das cartas | 20 mil arquivos por site; 25 MiB por arquivo; banda e requisições a arquivos estáticos sem limite | Recusa o deploy | [limites](https://developers.cloudflare.com/pages/platform/limits/) |
| Brevo Free | E-mail | 300 e-mails por dia. Sem domínio próprio, o Brevo troca o domínio do remetente por `@brevosend.com` (domínio gratuito, como gmail ou outlook, não pode ser autenticado) | Para de enviar até o dia seguinte | [Brevo](https://www.brevo.com/bulk-email-service/), [remetente](https://help.brevo.com/hc/en-us/articles/16045394674066) |
| Sentry Developer | Erros | 5 mil erros; 5 milhões de spans; 50 replays; 1 usuário; 30 dias de histórico | Descarta o excedente (sem cartão não existe pay-as-you-go) | [preços](https://sentry.io/pricing/) |
| GitHub Actions | CI, uptime, backup | Grátis em repositório público com runners padrão; job de até 6 h; workflow agendado é desligado depois de 60 dias sem atividade no repositório | — | [cobrança](https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions), [limites](https://docs.github.com/en/actions/reference/usage-limits-billing-and-administration) |

Descartados na conferência:

- **Cloudflare R2** (o escopo previa para imagens e backup): ativar o R2 pede cartão ou
  PayPal, e o que passa dos 10 GB grátis é cobrado. Fere as duas regras.
- **Resend Free** (3 mil e-mails por mês, 100 por dia): só envia para terceiros com um
  domínio verificado por DNS, e o projeto não tem domínio próprio.
- **VM Oracle Always Free** (plano B do escopo para o tempo real): o cadastro pede cartão,
  para verificação ([FAQ da Oracle](https://www.oracle.com/tryit.html)). Se um dia for
  preciso, é decisão do Pedro.

## Decisão

1. **Vercel Hobby para o front e a API.** O projeto é de fã e sem fins lucrativos (ADR
   0003), o que o Hobby exige. Prévias desligadas, deploy só quando muda o que vai para o ar
   (`scripts/vercel-ignorar-build.sh`) e limpeza das imagens antigas do container
   (`vercel-images.yml`).
2. **Região: tudo em São Paulo.** Funções em `gru1` (`regions` do `vercel.json`) e o
   projeto do Supabase em `sa-east-1`. Os jogadores estão no Brasil, cada consulta ao banco
   precisa ficar perto da função, e os dados dos jogadores ficam no país (LGPD). A região do
   Supabase é escolhida na criação do projeto: trocar depois exige migrar os dados.
3. **Conexão com o banco pelo pooler do Supabase.** No Free, o endereço direto do banco só
   tem IPv6. O Rails usa o pooler em modo transação (porta 6543), indicado para funções
   serverless, com `prepared_statements: false` (o modo transação não aceita prepared
   statements) e um pool pequeno. O `pg_dump` do backup, que roda no GitHub (IPv4), e as
   migrações, que usam trava de sessão (*advisory lock*), vão pelo modo sessão (porta 5432). Fonte: [conexões do Supabase](https://supabase.com/docs/guides/database/connecting-to-postgres).
4. **Imagens das cartas no Cloudflare Pages**, num projeto só de imagens, publicado por um
   workflow manual com `wrangler pages deploy` (F1). Não pede cartão, e banda e requisições
   não têm limite. Com 3 tamanhos por carta, os 20 mil arquivos comportam até 6.600 cartas.
   Na prática (GXP-26): projeto `gx-project-imagens`, workflow *Imagens das cartas*
   (`imagens.yml`), caminhos `/cards/{p,m,g}/<código>.webp` (112 e 268 de largura e a
   original, 813 x 1185), cache de um ano. São 3.423 cartas com imagem: 10.269 arquivos,
   uns 360 MB; as 61 do anime sem carta impressa ficam só com o texto. A imagem que já
   está no ar vem do próprio site na próxima execução: o YGOPRODeck só recebe pedido de
   imagem nova.
   As imagens não entram no repositório (ADR 0003). O Vercel Blob não serve aqui: 2 mil
   uploads por mês não sobem 3 tamanhos de milhares de cartas, e 10 GB de transferência
   acabariam rápido.
5. **Backup no Vercel Blob, em loja privada** (F2): `pg_dump` semanal numa Action,
   criptografado com `age` para uma chave pública guardada no repositório (a chave privada
   fica só com o Pedro), guardando os 4 últimos. Gasta umas 10 operações avançadas por mês
   e bem menos de 1 GB. O backup fica fora do Supabase de propósito.
6. **E-mail pelo Brevo Free** (F2), com um endereço de remetente só do projeto, nunca o
   pessoal. Sem domínio próprio, o remetente aparece como `@brevosend.com`. Um domínio
   próprio melhora a entrega, mas é pago: é decisão do Pedro.
7. **Erros no Sentry Developer**, com a proteção contra picos ligada e o ruído filtrado
   antes de enviar.
8. **Medir toda semana.** O resumo semanal mostra o uso de cada serviço e avisa acima de
   80% (escopo, 5.9). Ele também confere se o `uptime.yml` rodou: se o workflow agendado
   parar, o Supabase pausa em uma semana.

## Região: medição do navegador, em São Paulo

No navegador do Pedro (fuso `America/Sao_Paulo`), 30 chamadas seguidas ao `/up` (sem banco
e sem engine) mediram o caminho inteiro: rede, Vercel e Rails.

| Função em | p50 | p95 | mínimo | `x-vercel-id` |
| --- | --- | --- | --- | --- |
| `iad1` (Washington) | 168,7 ms | 243,8 ms | 161,4 ms | `gru1::iad1::…` |
| `gru1` (São Paulo) | 47,2 ms | 152,0 ms | 38,5 ms | `gru1::gru1::…` |

Uma segunda rodada em `gru1` deu p50 42,5 ms e p95 166,7 ms: o p95 varia com picos da rede
de casa, mas o p50 caiu para um quarto.

O Ably fica longe: do mesmo navegador, o REST do Ably (`/time`) responde em p50 129,6 ms. A
entrada é a CloudFront de São Paulo, mas o servidor que atende está em `us-east-1`. Cada
publicação do Rails custa então uns 130 ms, e isso entra na conta da ação (F3, abaixo).

## Quanto o jogo gasta

Por duelo 1x1, com base no duelo gravado dos bots (120 decisões, ADR 0002) e nos tempos
medidos da engine (ADR 0001). O que diz "estimado" ainda precisa ser medido na F3.

| Limite do mês | Gasto por duelo | Como chegou | Duelos por mês |
| --- | --- | --- | --- |
| Vercel: 1 milhão de invocações | ~130 | 120 decisões + ~10 de apoio (estado, token, resultado) | ~7.700 |
| Vercel: 4 h de CPU ativa | ~2 s | engine medida + Rails estimado em 10 ms por requisição, com 1 ação fria a cada 10 | ~7.000 |
| Vercel: 360 GB-h de memória | ~0,007 GB-h | estimado: 2 GB (o máximo do Hobby) × 100 ms por requisição | ~50.000 |
| Ably: 6 milhões de mensagens | 480 | ADR 0002 | ~12.500 |
| Supabase: 5 GB de saída | ~0,4 MB | estimado: ~1,5 KB por ação quente e ~15 KB por ação fria | ~12.500 |
| Supabase: 500 MB de banco | ~50 KB, por 30 dias | estimado: 403 respostas × ~130 bytes por linha, com os índices | ~9.000 nos últimos 30 dias, se o banco fosse só isso |

Conclusão: os planos grátis aguentam uns **7 mil duelos 1x1 por mês** (cerca de 230 por
dia), e o primeiro limite a chegar é o da Vercel (invocações e CPU). Antes disso, o Ably
segura 100 duelos 1x1 ao mesmo tempo (200 conexões). No Tag, com 4 jogadores, cada duelo
gasta perto do dobro.

## Consequências

- **Catálogo e coleção não podem ser lidos do banco a cada visita.** Um catálogo com
  milhares de cartas e textos passa de 1 MB: o Rails guarda o catálogo na memória e
  responde com cache na CDN (`s-maxage` e ETag pela versão dos dados), e a coleção do
  jogador responde com ETag.
- **Respostas do duelo:** uma linha por resposta, como no modelo de dados (escopo, 5.7),
  ocupa uns 50 KB por duelo. Na F3, medir; se passar de 20 KB por duelo, juntar as
  respostas da partida numa coluna só (por volta de 4 KB por duelo) e limpar os replays
  depois de 30 dias, como o escopo pede.
- **Publicar no Ably custa uns 130 ms por chamada.** Na F3: uma chamada só por ação (a
  publicação em lote do Ably manda a visão de cada jogador num pedido só), e o jogador que
  agiu recebe a própria visão na resposta HTTP. Medir se dá para publicar depois de
  responder.
- **O polling de reserva custa caro:** uma chamada a cada 2 s por jogador gasta mais
  invocações que o duelo inteiro. Ele só liga quando o Ably recusa.
- **Na Vercel, passar do limite derruba a API por até 30 dias.** O aviso dos 80% no resumo
  semanal é o que dá tempo de reagir: otimizar, desligar o que for opcional (imagens,
  polling) ou pedir ao Pedro uma decisão sobre plano.
- **Vistas do GitHub, as medições ficam mais lentas** em `gru1`, porque o runner está nos
  Estados Unidos: o `/up` passou a p50 283 ms. Dentro do app, a engine em `gru1` deu ação
  fria p50 34,1 ms e p95 70,5 ms, e quente p50 2,3 ms e p95 5,9 ms (*Medição da engine*, 50
  chamadas, 07/11/2026). O p95 da fria subiu de 42 para 70 ms, ainda longe dos 300 ms.
- **Conexão com o Supabase (GXP-23):** o projeto está em `sa-east-1`. Host, porta, usuário e
  banco ficam nas variáveis da Vercel (porta 6543) e do repositório no GitHub (o workflow
  *Banco de produção* usa a porta 5432). A senha fica só em `DATABASE_PASSWORD`: em partes,
  ninguém precisa montar a URL nem codificar caractere especial da senha. O Pedro cola a senha
  num lugar só, o secret do GitHub; o workflow *Banco de produção* copia para a Vercel
  (Production, Sensitive) pela API, com o `VERCEL_TOKEN`. Assim dá para fazer tudo pelo
  celular.

## Alternativas descartadas

- **Funções em `iad1` com o banco em `us-east-1`:** a publicação no Ably ficaria barata,
  mas toda requisição do jogador (duelo, Deck Edit, loja) pagaria uns 170 ms de ida e volta,
  mais da metade da meta de 300 ms. Em `gru1`, só a publicação paga, e ela pode sair do
  caminho da resposta.
- **Imagens no Supabase Storage:** a saída das imagens dividiria os 5 GB com o banco, e
  estourar a cota restringe o projeto inteiro, banco junto.
- **Imagens num repositório público do GitHub:** arte da Konami publicada como repositório,
  ligada à conta do Pedro.
