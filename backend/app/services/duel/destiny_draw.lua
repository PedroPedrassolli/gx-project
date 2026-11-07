-- Destiny Draw do GX Project, com a regra do jogo de referência, que mantém o sistema do
-- jogo anterior da série (Yugipedia: "Destiny Draw (rule)" e as páginas dos dois jogos):
-- * o lado está em apuros quando tem PV até 4000, o oponente controla monstro e nenhum
--   monstro do lado tem ATK maior que o do monstro mais forte do oponente;
-- * se a situação não virou até a segunda Fase de Compra, o duelista da vez pode usar: no
--   lugar da compra normal, compra uma das cartas Destiny que marcou, sorteada (aqui, ela
--   vai para o topo do deck antes da compra);
-- * uma vez por duelo para cada lado, inclusive no Tag.
--
-- Baseado na regra c511004000 do Project Ignis (CardScripts, AGPL-3.0). O servidor
-- (Duel::Engine) carrega este arquivo e depois chama GXDestinyDraw.setup.

GXDestinyDraw = {}

-- Mesmo código da regra do Project Ignis. A pergunta é aux.Stringid(ID, 0).
local ID = 511004000

-- ATK do monstro com face para cima mais forte do jogador (0 se não houver).
local function strongest_attack(player)
	local best = 0
	for card in aux.Next(Duel.GetMatchingGroup(Card.IsFaceup, player, LOCATION_MZONE, 0, nil)) do
		best = math.max(best, card:GetAttack())
	end
	return best
end

local function in_a_pinch(player)
	return Duel.GetLP(player) <= GXDestinyDraw.lp_limit
		and Duel.GetFieldGroupCount(player, 0, LOCATION_MZONE) > 0
		and strongest_attack(player) <= strongest_attack(1 - player)
end

-- Cartas Destiny do duelista da vez que ainda estão no deck. No Tag, a engine troca o
-- duelista do lado a cada turno dele: o k-ésimo turno do lado é do duelista
-- (k - 1) % (número de duelistas), na ordem em que o servidor mandou as listas.
local function destiny_cards(player)
	local lists = GXDestinyDraw.cards[player]
	local codes = lists[(Duel.GetTurnCount(player) - 1) % #lists + 1]
	if #codes == 0 then
		return Group.CreateGroup()
	end
	return Duel.GetMatchingGroup(Card.IsCode, player, LOCATION_DECK, 0, nil, table.unpack(codes))
end

function GXDestinyDraw.condition(effect, player)
	return Duel.GetTurnPlayer() == player and not GXDestinyDraw.used[player]
end

-- Roda no começo de cada Fase de Compra do lado, antes da compra. Conta há quantas Fases
-- de Compra seguidas o lado está em apuros; da segunda em diante (enquanto a situação não
-- virar), a pergunta aparece. Recusar não gasta.
function GXDestinyDraw.operation(effect, player)
	if in_a_pinch(player) then
		GXDestinyDraw.pinch[player] = GXDestinyDraw.pinch[player] + 1
	else
		GXDestinyDraw.pinch[player] = 0
	end
	local cards = destiny_cards(player)
	if GXDestinyDraw.pinch[player] < 2 or #cards == 0 or not Duel.SelectYesNo(player, aux.Stringid(ID, 0)) then
		return
	end
	GXDestinyDraw.used[player] = true
	Duel.Hint(HINT_CARD, 0, ID)
	-- O sorteio usa o gerador da engine, que segue a semente: o replay sorteia igual.
	Duel.MoveSequence(cards:RandomSelect(player, 1):GetFirst(), SEQ_DECKTOP)
end

-- lp_limit: o lado está em apuros com PV até esse valor.
-- cards[lado] = { {códigos do 1º duelista}, {códigos do 2º} } (no 1x1, uma lista só).
function GXDestinyDraw.setup(lp_limit, cards)
	GXDestinyDraw.lp_limit = lp_limit
	GXDestinyDraw.cards = cards
	GXDestinyDraw.used = { [0] = false, [1] = false }
	GXDestinyDraw.pinch = { [0] = 0, [1] = 0 }
	for player = 0, 1 do
		local effect = Effect.GlobalEffect()
		effect:SetType(EFFECT_TYPE_FIELD + EFFECT_TYPE_CONTINUOUS)
		effect:SetProperty(EFFECT_FLAG_CANNOT_DISABLE + EFFECT_FLAG_UNCOPYABLE)
		effect:SetCode(EVENT_PREDRAW)
		effect:SetCondition(GXDestinyDraw.condition)
		effect:SetOperation(GXDestinyDraw.operation)
		Duel.RegisterEffect(effect, player)
	end
end
