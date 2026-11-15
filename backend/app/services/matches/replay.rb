module Matches
  # Replay do duelo (escopo 3.7; GXP-56): a partida refeita do começo, numa cópia que não vai
  # para o banco, com um cache de engine só dela (as engines dos duelos em andamento ficam
  # onde estão). Cada pedido é um turno: a mesa de quem assiste depois de cada resposta.
  class Replay
    def initialize(match)
      @match = match
    end

    def turns = @match.turn

    def frames(team, turn)
      cache = Duel::EngineCache.new(1)
      copy = Match.new(@match.slice(:seed, :destiny_draw, :started_at))
      @match.players.each { |player| copy.players.build(player.slice(:team, :seat, :user_id, :deck)) }
      Game.new(copy, cache:).replay(team, @match.responses.map(&:bytes), turn)
    ensure
      cache.clear
    end
  end
end
