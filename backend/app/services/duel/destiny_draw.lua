-- Destiny Draw do GX Project, com as regras da série Tag Force (Yugipedia, "Destiny Draw
-- (rule)"): quando o lado está perdendo, o duelista da vez pode pôr no topo do deck uma
-- das cartas Destiny que marcou, sorteada. Perdendo quer dizer: PV abaixo do limite, o
-- oponente controla monstro e nenhum monstro do lado tem ATK maior que o do monstro mais
-- forte do oponente. Uma vez por duelo para cada lado, inclusive no Tag.
--
-- A fonte não diz em que momento do turno; aqui a pergunta vem no começo da Fase de
-- Compra (EVENT_PREDRAW), antes de comprar, como na regra do Project Ignis em que este
-- arquivo se baseia (CardScripts, c511004000.lua, AGPL-3.0).
--
-- O servidor (Duel::Engine) carrega este arquivo e depois chama GXDestinyDraw.setup.

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

local function losing(player)
	return Duel.GetFieldGroupCount(player, 0, LOCATION_MZONE) > 0
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
	return Duel.GetTurnPlayer() == player
		and not GXDestinyDraw.used[player]
		and Duel.GetLP(player) < GXDestinyDraw.lp_limit
		and losing(player)
		and #destiny_cards(player) > 0
end

-- Recusar não gasta: a pergunta volta no próximo turno do lado, se ele continuar perdendo.
function GXDestinyDraw.operation(effect, player)
	if not Duel.SelectYesNo(player, aux.Stringid(ID, 0)) then
		return
	end
	GXDestinyDraw.used[player] = true
	Duel.Hint(HINT_CARD, 0, ID)
	-- O sorteio usa o gerador da engine, que segue a semente: o replay sorteia igual.
	Duel.MoveSequence(destiny_cards(player):RandomSelect(player, 1):GetFirst(), SEQ_DECKTOP)
end

-- lp_limit: PV abaixo do qual vale a regra.
-- cards[lado] = { {códigos do 1º duelista}, {códigos do 2º} } (no 1x1, uma lista só).
function GXDestinyDraw.setup(lp_limit, cards)
	GXDestinyDraw.lp_limit = lp_limit
	GXDestinyDraw.cards = cards
	GXDestinyDraw.used = { [0] = false, [1] = false }
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
