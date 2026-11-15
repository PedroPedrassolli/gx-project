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

9. **A resposta do jogador** (`POST /api/matches/:id/responses`) leva a escolha em JSON
   (comando e índice, sim ou não, índices das cartas...), que o `Duel::ResponseEncoder` vira
   os bytes que a engine espera. Ele só confere a forma; a engine diz se a jogada vale (se
   não vale, 422 e nada muda). A partida fica travada durante a resposta, e o `seq` (quantas
   respostas o jogador viu) evita jogar sobre uma mesa velha (409).
10. **Depois da resposta, cada outro jogador recebe a mesa inteira dele** (`duel.updated`),
    não só o que mudou: a tela troca a mesa toda, e o que veio fora de ordem se resolve
    sozinho. Quem respondeu recebe a mesa nova na própria resposta HTTP.
11. **O texto das perguntas vem do servidor:** cada descrição (efeito, opção, cadeia, sim ou
    não) é (código da carta << 20) | número do texto, e o servidor põe ao lado o texto
    `strN` da carta no BabelCDB, em inglês, que é o que existe. O Destiny Draw tem o próprio
    texto em português. As perguntas do próprio jogo (sem carta) a tela descreve. A dica do
    que escolher, que a engine manda antes da pergunta (ex.: 502, a carta para destruir), vai
    junto dela (`hint`, e `hint_text` quando é de uma carta).
12. **A zona da carta que vai para o campo o servidor escolhe sozinho** (`Matches::AutoPlace`),
    do centro para as pontas, a mesma ordem que a engine usa quando joga sozinha. Assim a
    invocação não para numa pergunta a mais e o duelo anda rápido. No MR1 a zona quase nunca
    muda o jogo; a zona que um efeito manda escolher para desativar (`select_disfield`)
    continua com o jogador.
13. **O log e a corrente da mesa vêm dos eventos** (`Duel::Events`): cada ação lê das
    mensagens da engine a compra, a invocação, a carta baixada, a carta que muda de lugar ou
    de posição, a corrente (ativação, negação, resolução), o ataque, os PV, os sorteios e o
    fim. A partida guarda os últimos 50 eventos, numerados (o que cada lado ainda não viu
    sai pelo número, também nas consultas sem tempo real), e os elos da corrente aberta. Os
    eventos ficam com os códigos no banco; cada lado recebe só o que vê, com as regras da
    mesa: a compra do outro sem as cartas, a carta baixada sem código e a carta que muda de
    lugar só aparece se estava ou fica à vista. O ataque leva o código das cartas com a face
    para cima, lido da mesa logo depois da declaração (antes da batalha).
14. **O tempo** (`Matches::Clock`, escopo 3.7): cada pergunta tem 90 s; o jogador da vez tem
    ainda um banco de 5 min para o turno inteiro, que só gasta enquanto a pergunta é dele e
    volta inteiro no turno seguinte; o duelo inteiro tem 60 min, e no fim ganha quem tem mais
    PV (iguais, empate). Quem deixa o prazo passar perde, e isso cobre também quem cai e não
    volta ("desconexão vira derrota depois do prazo"). Não há processo esperando o relógio:
    a partida vencida se encerra na próxima consulta ou resposta (a tela de quem espera
    consulta quando o tempo zera). Os números são o padrão do projeto e mudam num lugar só.
15. **Desistir** (`POST /api/matches/:id/surrender`) encerra a partida com a vitória do
    outro. Sair da sala no meio do duelo não vale: primeiro se desiste. Em qualquer fim, a
    sala volta a esperar, com todos "não pronto": a revanche é ficar pronto de novo.

## Consequências

- Partidas e respostas crescem com cada duelo. O replay vale 30 dias (escopo 3.7); a limpeza
  entra com o replay (GXP-56).
