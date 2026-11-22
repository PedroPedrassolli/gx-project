# ADR 0013: duelos contra personagens

- **Data:** 21/11/2026
- **Situação:** aceita (GXP-100). O computador, a API e a tela entram em GXP-101 a GXP-103.

## Contexto

Em 20/11/2026 o Pedro tirou o duelo em dupla (o projeto é pequeno, não haveria gente para
formar duplas) e pediu, no lugar, duelos contra personagens do anime: com desafio, divertidos,
com o deck deles sempre embaralhado e uma ordem para liberar. "O Yugi não perderia no anime,
aqui deve ser possível vencer."

## Decisão

1. **14 personagens, nesta ordem:** alunos da Academia (Chumley, Syrus, Blair, Alexis, Chazz,
   Bastion), chefes (Zane, Crowler, Jesse, Aster, Jaden) e lendas de Duel Monsters (Joey, Kaiba
   e o Yugi por último). Vencer um libera o próximo. O grupo diz como o computador joga: 1 nos
   alunos (erra de propósito às vezes), 2 nos chefes e 3 nas lendas.
2. **O deck de cada um é o do jogo de referência.** As páginas de personagem da Yugipedia têm a
   lista completa de cada deck que ele usa no jogo, com um nível de 1 a 10. Foram lidas pela API
   em 21/11/2026 e cada nome de carta passou pelos redirecionamentos da Yugipedia até o nome
   atual, que é o do `cartas.yml`. Para cada personagem ficou um deck com o tema dele no anime
   (coalas do Chumley, Armed Dragon do Chazz, Ancient Gear do Crowler, Neos do Jaden...).
3. **Yugi, Kaiba e Joey não estão no jogo de referência.** Usam o deck deles em outro jogo da
   série. O do Joey cabe inteiro no pool; nos outros dois, 7 cartas não existem aqui e foram
   trocadas por cartas que eles usam no anime: no Kaiba, Obelisk the Tormentor por Vorse
   Raider e 2 The Melody of Awakening Dragon por Trade-In; no Yugi, Slifer the Sky Dragon por
   Dark Magician Girl, Black Illusion por Dark Magic Attack e 2 Dark Renewal por Magical Hats e
   Spellbinding Circle. As trocas ficam escritas no YAML.
4. **`db/seeds/jogo/personagens.yml`, escrito à mão** a partir dessas listas, com a revisão de
   cada página como fonte (sem o título, que tem o nome do jogo; ADR 0003). Um teste confere
   cada deck contra o pool: carta com código na engine, de 40 a 60 no Main, até 15 no Extra
   (só Fusão e Sincro), até 3 cópias e a carta-símbolo dentro do deck.
5. **Sem banlist nos dois lados.** Os decks dos personagens no jogo de referência também não
   seguem a banlist dele (o Chumley tem Monster Reborn e Heavy Storm). O deck do jogador só
   precisa valer sem banlist.
6. **Prêmio:** o DP do duelo como contra um amigo, sem o bônus "vitória em rede", mais um
   bônus na vitória de 60 DP vezes a posição na ordem (60 no Chumley, 840 no Yugi). Na
   primeira vitória contra cada personagem, a carta-símbolo dele vai para a coleção, uma vez
   só. **Desistir ou deixar o tempo passar contra o computador paga como duelo curto**: sem
   isso, bastaria começar um duelo e desistir depois de 3 turnos para levar o prêmio de 300.
7. **O computador não trapaceia.** Ele responde às mesmas perguntas da engine, pela mesma
   validação do jogador, olhando só a mesa que um jogador veria do lado dele (`Duel::View`).
   Joga por regras simples (invocar o mais forte, atacar o que vence, ativar a armadilha no
   ataque ou na invocação do oponente) e, quando a regra não sabe o que fazer, escolhe ao acaso
   entre as opções válidas, como o robô dos testes (`Bots::RandomPlayer`, que saiu de
   `test/support` para `app/`). Nos alunos, 20% das escolhas são ao acaso de propósito e só 60%
   das armadilhas saem na hora; nos chefes, 7% e 90%; nas lendas, nenhuma e todas.
8. **No `Matches::Game`:** o lugar do computador é um `match_players` sem conta e com o
   `character` preenchido. Depois de cada resposta, o jogo responde sozinho tudo o que é do
   computador até a pergunta voltar para o jogador. Se a engine recusar a jogada dele, ele
   tenta ao acaso (até 50 vezes); se nada valer, desiste e o jogador vence (não deveria
   acontecer; fica no log).
9. **Começar o duelo** (`POST /api/characters/:id/duels`, com um deck do jogador): só com o
   personagem liberado, sem outro duelo em andamento e fora de sala (quem duela contra
   personagem também não entra em sala). Quem começa é sorteado. **Sem relógio**: contra o
   computador dá para pensar com calma, e o duelo largado fica esperando a volta do jogador (o
   aviso "Voltar para a mesa" aparece em todas as telas). As vitórias ficam em
   `character_wins` (uma linha por jogador e personagem), que também entram no arquivo da LGPD.

## Consequências

- Mudar um deck é editar o YAML; o teste diz se a lista nova vale.
- O computador joga no mesmo pedido da jogada do jogador: o turno dele chega de uma vez e os
  eventos animam na mesa como os de um oponente de verdade.
- O computador não vai jogar como uma pessoa. A dificuldade vem mais do deck (os das lendas e
  dos chefes são os mais fortes de cada um no jogo) do que da esperteza das escolhas.
