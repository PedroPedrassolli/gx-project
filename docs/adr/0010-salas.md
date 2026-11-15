# ADR 0010: salas de duelo

- **Data:** 14/11/2026
- **Situação:** aceita (GXP-46)

## Contexto

A F3 é o duelo 1x1 em sala (escopo 3.6 e 8): sala pública ou privada, com código de 6
caracteres, opções (banlist, Destiny Draw), "pronto" e expulsar antes de começar. O modelo
de dados do escopo (5.7) cita `rooms` com as opções em jsonb, mas não diz onde ficam os
jogadores enquanto a partida não começa.

## Decisão

1. **Duas tabelas:** `rooms` (código, dono, pública, modo, `best_of`, banlist, Destiny
   Draw, situação) e `room_players` (lugar, jogador, deck escolhido, pronto). As opções são
   colunas, não jsonb: cada uma tem tipo e valor padrão, e o banco recusa o que não existe.
   O formato virou `best_of` (1 agora, 3 na F5) porque `format` esconderia o
   `Kernel#format` no modelo.
2. **Código sem 0, O, 1 e I** (32 caracteres, uns 1 bilhão de códigos): é lido em voz alta
   ou copiado à mão.
3. **Um jogador fica numa sala só** (índice único em `room_players.user_id`). Criar ou entrar
   em outra sala tira o jogador da anterior, se ela ainda espera; durante o duelo, não dá.
   Dois pegando o último lugar ao mesmo tempo: o índice único de (sala, lugar) deixa um só.
4. **Se o dono sai, a sala fecha** (é apagada) e quem ficou recebe `room.closed`. Sala não
   guarda histórico; a partida (GXP-48) é que guarda o duelo.
5. **A lista mostra as salas públicas que esperam gente e mexeram na última hora**
   (`Room::LISTED_FOR`): entrar, sair ou ficar pronto atualiza a sala (`touch`).
6. **O deck escolhido só aparece para o dono dele.** Os outros veem se já escolheu e se está
   pronto.
7. **Tempo real:** cada mudança manda `room.updated` para cada jogador, com a sala vista por
   ele. Se o Ably falhar, o pedido segue: o front também consulta `GET /api/rooms/:code`.

## Consequências

- Sala esquecida (ninguém clicou em sair) continua no banco e prende o jogador nela até ele
  entrar em outra. A lista esconde depois de 1 hora; a limpeza fica para quando incomodar.
- Cada aviso é um POST no Ably, um por jogador. Com 2 jogadores dá conta; a publicação em
  lote, com a conexão reaproveitada, vem com a ação do duelo (GXP-50), que publica muito mais.
