# ADR 0005: economia (DP, nível, pacotes e anti-farm)

- **Data:** 07/11/2026
- **Situação:** aceita (GXP-8; nível, chances e missões no GXP-22). O código entra na F4; os valores do jogo vêm do GXP-6.

## Contexto

O escopo (3.4 e 3.5) define a economia: o jogador ganha DP no fim de cada duelo pela soma
dos bônus do Anexo A, sobe de nível, cumpre desafios e gasta DP em pacotes. Os módulos e as
tabelas já estão no escopo (5.2 e 5.7): `Economy::Ledger`, `BonusCalculator`,
`LevelService`, `ChallengeEvaluator`, `AntiFarm`, `Shop::PackOpener`, `Shop::Converter`,
`dp_transactions` e `pack_openings`.

O que pode dar errado: pagar o mesmo duelo duas vezes (requisição repetida, clique duplo),
saldo negativo com duas compras ao mesmo tempo, sorteio que dá para prever ou manipular, e
farm de DP entre contas combinadas.

## Decisão

1. **Razão de DP imutável.** Toda mudança é uma linha nova em `dp_transactions`: jogador,
   `motivo`, `valor` (inteiro; positivo é crédito, negativo é débito), `saldo_apos`, `ref`
   polimórfica (partida, abertura de pacote, ajuste do admin), `chave` de idempotência e,
   no ajuste do admin, uma nota. Nada de `UPDATE` ou `DELETE`; o model é só leitura depois
   de criado. O saldo é o `saldo_apos` da última linha do jogador. A exclusão da conta
   (LGPD) apaga as linhas junto com o jogador.
2. **Lançamento atômico.** `Economy::Ledger` trava a linha do jogador (`SELECT … FOR
   UPDATE`), lê o último saldo, recusa débito que deixaria o saldo negativo
   (`Economy::SaldoInsuficiente`) e grava a linha. Quem chama (compra, fim de duelo) faz o
   resto na mesma transação: tudo entra junto ou nada entra.
3. **Idempotência pela chave.** Índice único em (jogador, `chave`). Repetir a chave devolve
   o lançamento que já existe, sem cobrar nem pagar de novo. Fim de duelo: `partida:{id}`.
   Compra: o front manda um UUID por clique no cabeçalho `Idempotency-Key`.
4. **Bônus por função pura.** `BonusCalculator` recebe as estatísticas do duelo e a tabela
   do Anexo A (seed YAML) e devolve as linhas (bônus, vezes, DP) e o total. Não lê banco
   nem relógio. A tela de resultado mostra as linhas; o total vira um lançamento só.
5. **Anti-farm também puro**, aplicado depois do bônus e antes do crédito, com os valores
   do admin (padrões do escopo, 3.5):
   - duelo com menos de 3 turnos ou menos de 2 minutos paga só a derrota (10 DP);
   - contra o mesmo oponente no mesmo dia: 100%, 50%, 25% e depois 0 (no Tag, o oponente é
     a dupla adversária);
   - teto diário para o DP vindo de salas (3.000), pela metade em contas com menos de 7
     dias.
   O "dia" é o de São Paulo (`America/Sao_Paulo`). O resultado traz o motivo de cada corte,
   e a tela mostra.
6. **Nível:** a fonte não traz a regra do jogo, e o Pedro pediu uma inspirada nele (Anexo
   C, 07/11/2026). `LevelService` sobe 1 nível a cada 1.000 DP ganhos, do 1 ao 99, com o
   valor no admin. Assim os pacotes que o jogo libera entre os níveis 21 e 50 chegam aos
   poucos. `dp_ganho_total` soma só os créditos e é atualizado na mesma transação do
   lançamento; cada subida paga o bônus de nível do Anexo A.
7. **Sorteio só no servidor, com semente gravada.** `Shop::PackOpener` gera a semente com
   `SecureRandom`, sorteia com `Random.new(semente)` e grava a semente e as cartas em
   `pack_openings`. A mesma semente dá as mesmas cartas, o que permite testar e auditar. A
   fonte não traz as chances do jogo, então cada carta do pacote sorteia primeiro a
   raridade, com os pesos comum 75, rara 18, super rara 5 e ultra rara 2 (padrão, no
   admin), só entre as raridades que o pacote tem, e depois uma carta dessa raridade.
   Comprar 1 ou 10 pacotes é uma transação só, com uma chave.
8. **Conversor** (`Shop::Converter`): uma transação, com o sorteio do mesmo jeito (semente
   gravada). Nunca consome a cópia que um deck usa sem cópia sobrando (escopo, 3.4).
9. **Missões** (`backend/db/seeds/missoes.yml`, Anexo C): liberam os 8 pacotes que no
   jogo dependiam de minigame, torneio ou história e as 18 cartas que só saíam por
   download ou minigame. Cada missão é avaliada no fim do duelo, como os desafios, e os
   números ficam no admin.
10. **Nenhum valor inventado.** Preços, bônus e grupos do conversor vêm dos dados do GXP-6,
    com fonte. O que é decisão do projeto (chances, regra de nível, missões) está marcado
    como tal e fica no admin.

## Como ficou na F4 (GXP-85, 15/11/2026)

- **Razão:** `dp_transactions` (`Economy::Ledger`), com o jogador travado em cada lançamento,
  chave única por jogador (`partida:ID`, `nivel:N`) e débito que deixaria o saldo negativo
  recusado. O saldo é o `balance_after` da última linha; `users.dp_earned` soma só os créditos.
- **Bônus do fim do duelo** (`Economy::BonusCalculator`, sem banco nem relógio): nível (2 ×
  nível), derrota (10), empate (50), turnos (2 por turno na vitória, 1 nos outros casos),
  vitória em rede (50), duelista (90 × faixa do oponente, 1 a 10, só na vitória, como no jogo)
  e as formas de vencer que saem da mesa no fim: oponente sem cartas (20), até 5 turnos (10),
  no turno do oponente (20), PV abaixo de 1.000 (20) e de 100 (100), acima de 20.000 (100),
  exatamente 5.730 (573), deck com menos de 10 (20) e vazio (100), Exodia (50), Contagem Final
  (50), Quadro do Destino (100) e Último Turno (50). As formas de vencer só contam quando o
  duelo acabou na engine: desistência e tempo não valem. Os que precisam das estatísticas do
  duelo inteiro (dano, destruições, invocações...) estão no item das estatísticas, abaixo.
- **Estatísticas do duelo** (GXP-87, `Duel::Stats`): a cada jogada, as mensagens da engine
  viram contas por time em `matches.stats` (dano de batalha, de efeito, direto e refletido;
  invocações Normal, Virada, Especial, de Tributo, de Fusão e de Ritual; magias e armadilhas
  ativadas; cartas destruídas, removidas, descartadas e devolvidas; corrente; marcadores de
  magia; União; moeda; maior ATK). O robô de duelos confere, no fim de cada duelo, que o PV
  contado bate com o da engine. Com elas entram os bônus 14, 19 e 24 a 50 do Anexo A, o golpe
  final de Skull Servant (57) e os de invocar ou usar certas cartas (58 a 82, pelo nome no
  catálogo). O uso de cartas (24 a 31) vale em qualquer vitória; os feitos (32 a 36 e 40 a 50),
  ganhando ou não.
  - **Quem fez:** a engine não diz de quem é o efeito que destruiu, removeu ou descartou uma
    carta. Vale o dono do elo da corrente que está resolvendo; fora de corrente, o oponente do
    dono da carta. Só contam cartas do oponente.
  - **Magia ou armadilha ativada** é a carta que acabou de ser virada para cima (da mão ou
    baixada) e entrou na corrente; o efeito de uma carta que já estava aberta não conta.
  - **Moeda:** acerto é cair o lado que o jogador disse; na carta que não pergunta, cara. O
    dado não entra (a fonte não diz o que é ganhar no dado).
  - **Fora, por falta de regra na fonte:** "nenhuma zona de monstro livre para o oponente"
    (51), "carta-chave do oponente" (52) e o "New Bonus" (83). Tag e Match (07, 09 e 16) vêm
    com a F5 e a F6.
- **Anti-farm** (`Economy::AntiFarm`): duelo com menos de 3 turnos ou de 2 minutos paga só 10
  DP; contra o mesmo oponente no dia (fuso de São Paulo), 100%, 50%, 25% e depois nada; teto de
  3.000 DP por dia em duelos, 1.500 nas contas com menos de 7 dias. Os valores ficam em
  constantes até existir o admin (F7).
- **Nível:** cada nível novo paga 400 DP, que também contam para o próximo nível.
- **Desafios** (GXP-88, `Economy::Challenges`): os 104 do jogo, com o texto em português e a
  condição de cada um, conferidos no fim do duelo com as estatísticas e com o deck usado
  (`user_challenges` guarda os concluídos; cada um conta uma vez). Cada desafio concluído paga
  2 DP em todo duelo (bônus 03). Decisões: "vencer" é vencer na engine (desistência e tempo não
  concluem desafio, senão dois amigos trocariam desistências); os de contagem (1 a 24 e a
  moeda) valem ganhando ou não; "deck" é o Deck Principal, a não ser quando o desafio fala do
  Extra; "só com monstros de..." pede pelo menos um monstro; a série XYZ são as sete cartas (X,
  Y, Z e as quatro fusões); o deck de 80 cartas do original virou o de 60, o máximo aqui. Três
  ficam sem condição e aparecem como "Em breve": os dois de Match (F5) e o da trava de
  Yata-Garasu (a fonte não diz como o jogo reconhece). Os pacotes que pedem "todos os
  desafios" pedem os 101 que dá para concluir. A página `/desafios` mostra o progresso.
- **Loja** (GXP-86): `GET /api/shop` traz o saldo, o nível e cada pacote com a dica de como
  liberar (`Shop::Availability`, pelo `disponibilidade.yml`; missões e códigos ficam bloqueados
  até o GXP-89, e a dica nunca mostra o código). `POST /api/shop/purchases` (1 ou 10
  pacotes, com a chave da compra) roda numa transação: jogador travado, pacote liberado,
  débito no razão (`compra:CHAVE`), sorteio (`Shop::Draw`: pesos 75, 18, 5 e 2 entre as
  raridades que o pacote tem) com a semente gravada em `pack_openings` e as cartas na coleção.
  A mesma chave devolve a mesma compra, sem cobrar de novo. A carta "nova" é a que o jogador
  ainda não tinha (só a primeira cópia dela na compra).
- **Resultado:** o resumo (linhas, cortes, subida de nível, total, nível e saldo) fica em
  `match_players.rewards`, com os textos prontos, e a mesa devolve o de quem consulta. O saldo
  e o nível também vão no usuário da sessão (topo da página no computador e a página da conta).

## Consequências

- Testes primeiro (F4): um por bônus do Anexo A, o anti-farm em tabela de casos, o sorteio
  pela semente e o razão com duas threads debitando ao mesmo tempo (esse teste roda fora da
  transação de teste, com banco de verdade).
- O saldo sai de uma consulta indexada (jogador, id), sem coluna de saldo para manter em
  dia.
- A trava é por jogador: compras do mesmo jogador entram em fila; jogadores diferentes não
  se esperam.
- O razão gasta pouco banco: uma linha por jogador por duelo e uma por compra.

## Alternativas descartadas

- **Coluna de saldo em `users`:** seria uma segunda fonte da verdade, e o escopo proíbe
  editar o saldo direto.
- **Trava otimista (coluna de versão):** exige repetir a operação em caso de conflito. Com
  o volume do jogo, a trava da linha é mais simples.
- **Sorteio no navegador ou semente previsível (hora, id):** dá para manipular ou prever.
