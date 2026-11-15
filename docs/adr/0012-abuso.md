# ADR 0012: abuso de salas e partidas

- **Data:** 15/11/2026
- **Situação:** aceita (GXP-67).

## Contexto

O duelo 1x1 está no ar para jogar com a família e os amigos, mas a sala é aberta a qualquer
conta. Pedido do Pedro: ninguém pode abusar dos pontos ganhos nem fazer spam de duelos falsos.
A F3 ainda não paga DP; a F4 paga, com o anti-farm do [ADR 0005](0005-economia.md).

## Decisão

1. **O resultado sai só do servidor:** da engine (PV a zero, deck vazio, vitória especial),
   do relógio (prazo e limite de 60 minutos) ou da desistência de quem perde. Nenhuma rota
   recebe o vencedor; o cliente manda só a resposta à pergunta da vez, que a engine confere
   (a que não vale volta 422 e não é gravada).
2. **Uma vaga por conta** (índice único em `room_players.user_id`): ninguém joga duas
   partidas ao mesmo tempo nem ocupa os dois lugares da mesma sala.
3. **O deck é conferido de novo no começo do duelo** (`Matches::Start`), não só no "pronto":
   deck mexido depois disso (incompleto, fora da coleção ou da banlist) tira o dono do
   "pronto" e o duelo espera.
4. **Limites por IP** (Rack::Attack, contadores no Solid Cache): salas 60 por minuto,
   jogadas e desistência 240, consultas da mesa 240 e token do tempo real 30. Folgados para
   duas pessoas na mesma casa; barram robô, que gastaria banco, engine e a cota do Ably.
5. **Cada um vê só o que pode:** a mesa e o histórico de cada time passam pelo
   `Duel::View` e pelo `Duel::Events`; os duelos do robô conferem, a cada resposta, que a mão,
   as cartas viradas e o deck do outro não vazam.
6. **A partida já guarda o que o anti-farm da F4 precisa:** os jogadores
   (`match_players.user_id`), os turnos (`turn`), o começo e o fim (`started_at`,
   `finished_at`) e o motivo (`finish_reason`). Desistência e tempo esgotado contam como
   qualquer fim: duelo curto paga só a derrota, e o mesmo oponente no mesmo dia rende cada vez
   menos.

## Consequências

- Duas contas da mesma pessoa ainda conseguem duelar entre si. Na F3 isso não rende nada; na
  F4, as regras do ADR 0005 limitam o ganho, e o cadastro já tem limite por IP.
- Um IP muito dividido (escola, rede de celular) pode bater no limite de salas; a resposta
  429 diz para esperar um pouco.
