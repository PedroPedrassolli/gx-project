# ADR 0007: API do catálogo

- **Data:** 07/11/2026
- **Situação:** aceita (GXP-27).

## Contexto

O escopo (5.6) pede a API REST em JSON no prefixo `/api`, com `cards` (busca e filtros),
pacotes e banlists. O ADR 0004 diz que o catálogo não pode ser lido do banco a cada visita:
o Rails guarda na memória e a CDN guarda as respostas. O único cliente é o nosso front, no
mesmo domínio e no mesmo repositório.

## Decisão

1. **Rotas:** `GET /api/cards`, `GET /api/cards/:id`, `GET /api/packs` e `GET /api/banlists`.
   Sem versão no caminho (`/api/v1`): quando o contrato mudar, o front muda no mesmo PR.
   Sem chave de API e sem CORS: o catálogo é público e o front está no mesmo domínio.
2. **Catálogo na memória:** `Catalog::Snapshot` lê cartas, pacotes e banlists uma vez, guarda
   como hashes e relê a cada 5 minutos. Os filtros rodam em Ruby (umas 3.500 cartas, 2 ms
   por busca); carregar leva uns 250 ms.
3. **Filtros (escopo 3.3):** `q` (nome em inglês, em português ou o do jogo, sem acento e
   sem caixa), `card_type`, `property`, `attribute`, `race`, `monster_type`, `level`,
   `atk_min`/`atk_max`, `def_min`/`def_max` (quem tem ATK ou DEF "?" fica de fora da faixa),
   `pack` (cada carta vem com a raridade no pacote), `sort` (`name`, `atk`, `def`, `level`,
   `type`) e `order=desc`. Valor que não existe devolve a lista vazia, sem erro.
4. **Sem paginação:** o catálogo inteiro cabe numa resposta (3.484 cartas, 516 KB, 84 KB
   comprimida). O front pode filtrar e ordenar na própria lista, sem ir à rede a cada letra.
   A lista traz o resumo; o detalhe (`/api/cards/:id`) traz os textos, os pacotes e o link
   da revisão da Yugipedia (crédito da CC BY-SA).
   `/api/cards/details` traz o detalhe de todas as cartas, pelo id, sem o que a lista já
   tem (GXP-121): o front baixa em segundo plano logo depois da lista, e o texto de qualquer
   carta aparece na hora; o detalhe de uma carta sozinha fica como plano B.
5. **Cache:** `Cache-Control: public, max-age=300, s-maxage=3600, stale-while-revalidate=2592000`
   e ETag pela versão dos dados (um resumo do conteúdo) junto com os parâmetros. Pedido com
   `If-None-Match` igual recebe 304. A cópia velha vale 30 dias na CDN (era 1 dia até
   15/11/2026): o servidor desliga depois de 5 minutos parado e leva uns 4 s para acordar,
   e quem voltava depois de mais de 25 horas esperava isso e mais a montagem do catálogo.
   A Vercel tira o `s-maxage` e o `stale-while-revalidate` do que chega ao navegador; ele
   fica só com os 5 minutos. Não vale contornar isso: com `stale-while-revalidate`, o
   Safari baixa a lista inteira de novo em vez de receber 304 (bug 275248 do WebKit).
   Além disso, o front guarda a última lista e os textos no navegador (Cache Storage,
   GXP-122): na volta ao site, a tela abre com essa cópia, sem esperar o servidor acordar
   nem a CDN de um deploy novo, e troca pela resposta nova quando ela chega.
6. **Formato:** `{ data, meta }` (`meta.total` e `meta.version`); erro como
   `{ error: { status, message } }`. Campo vazio não vai na resposta. Os valores ficam como
   a Yugipedia escreve (`Monster`, `DARK`, `Fiend`, `ultra_rare`); a tela traduz. O id é o do
   banco, que o importador mantém entre uma carga e outra.

## Consequências

- Uma importação nova aparece em até 30 s no Rails (GXP-120: uma consulta barata confere se
  o banco mudou, e o catálogo só é remontado quando muda), 1 hora na CDN (a partir da
  segunda visita, porque a primeira recebe a cópia velha e dispara a busca da nova) e 5
  minutos no navegador. Cada deploy tem a própria CDN, que começa vazia: o primeiro pedido
  depois de um deploy espera o servidor.
- Cada visitante sem cache baixa uns 84 KB da lista inteira; com a CDN, a função quase não
  roda, e o banco é lido de novo só quando o catálogo muda. Ao subir, o servidor já monta o
  catálogo em segundo plano.
- Mudar um filtro ou um campo é mudar o contrato com o front: os dois mudam juntos, com os
  testes de request de cada rota.
