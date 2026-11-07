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
