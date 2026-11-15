# ADR 0011: partidas

- **Data:** 14/11/2026
- **Situação:** aceita (GXP-48). Cresce com a visão do duelo e a ação (GXP-49 e GXP-50).

## Contexto

Quando todos da sala estão prontos, o duelo começa (escopo 3.7 e 5.4). O estado do duelo é a
semente, os decks e a lista de respostas: a engine refaz o resto (ADR 0001).

## Decisão

1. **Três tabelas** (escopo 5.7): `matches` (sala, modo, opções copiadas da sala, semente,
   situação, time vencedor, começo e fim), `match_players` (time, lugar na sala, jogador e o
   deck do jeito que entrou no duelo) e `match_responses` (ordem, time que respondeu e os
   bytes da resposta).
2. **O último a ficar pronto começa o duelo** (`Matches::Start`), com a sala travada (`lock!`):
   dois "pronto" ao mesmo tempo não criam duas partidas. Os dois jogadores recebem
   `match.started`, e a sala em duelo diz qual é a partida (`match_id`).
3. **O deck guardado já vem embaralhado** (`SecureRandom`): a engine não embaralha no começo,
   e o replay precisa da mesma ordem. A semente são quatro números de 63 bits (a engine pede
   quatro de 64; 63 cabem no `bigint` do Postgres).
4. **Quem começa sai num sorteio por enquanto.** A pedra, papel e tesoura do escopo (3.7),
   com quem ganha escolhendo ir primeiro ou segundo, vem depois de o duelo funcionar.
5. **A partida fica quando a sala some** (o banco tira a sala dela) e quando alguém apaga a
   conta (o jogador some da partida): o replay é do outro jogador também.
6. **A engine roda já no começo** (`Matches::Game#start!`), até a primeira pergunta de verdade.
   A partida guarda o que a engine não guarda e a tela precisa: o turno, de quem é a vez, a
   fase e a pergunta da vez (com o time que responde), lidos das mensagens.
7. **Cadeia sem opção o servidor responde sozinho** ("não encadear") e grava a resposta: o
   jogador só é consultado se tiver o que fazer (escopo 3.7).
8. **A mesa de cada jogador sai das consultas à engine** (`Duel::View`), não de remontar o
   estado pelas mensagens. Cada um vê a própria mão e o próprio Extra; do outro, só a
   quantidade. Carta virada para baixo do outro mostra só a posição. As perguntas não levam o
   código de carta escondida do outro (na mão, no deck, no Extra ou virada no campo).

## Consequências

- Partidas e respostas crescem com cada duelo. O replay vale 30 dias (escopo 3.7); a limpeza
  entra com o replay (GXP-56).
