module Economy
  # As missões (db/seeds/missoes.yml; escopo 3.5; GXP-89): contam as vitórias do jogador e,
  # quando ele chega ao objetivo, liberam pacotes na loja ou dão uma carta.
  #
  # A vitória que conta (match_players.mission_win, marcada por Economy::DuelRewards) não foi
  # num duelo curto e é no máximo a 3ª do dia contra o mesmo oponente: as mesmas réguas do
  # anti-farm, para dois amigos não encherem as missões trocando desistências.
  class Missions
    FILE = Rails.root.join("db/seeds/missoes.yml")
    # O período da missão que só vale uma vez (a semanal usa a semana; a que sempre repete, a partida).
    ONCE = "once"
    GOALS = { "vitorias" => "Vencer %d duelos", "vitorias_no_mesmo_domingo" => "Vencer %d duelos no mesmo domingo",
              "vitorias_na_semana" => "Vencer %d duelos na mesma semana", "vitorias_seguidas" => "Vencer %d duelos seguidos" }.freeze
    # Quantas partidas para trás a sequência de vitórias olha.
    STREAK_LOOKBACK = 200

    def self.all = @all ||= YAML.safe_load_file(FILE)
    def self.name_of(id) = all.find { |mission| mission["id"] == id }&.fetch("nome")

    def initialize(user)
      @user = user
    end

    # Para a tela: cada missão com o objetivo, o prêmio, quanto o jogador já fez e se concluiu.
    def progress
      self.class.all.map do |mission|
        goal, target = mission["objetivo"].first
        value = count(goal)
        { id: mission["id"], name: mission["nome"], goal: format(GOALS.fetch(goal), target), reward: reward_text(mission),
          progress: goal == "vitorias_seguidas" ? value % target : [ value, target ].min, target:,
          done: done.include?([ mission["id"], period(mission, nil) ]), repeats: mission.key?("repete") }
      end
    end

    # Depois de uma vitória que conta: conclui as missões que chegaram ao objetivo e devolve o
    # que cada uma deu ({ name:, card:, packs: }).
    def award(match)
      self.class.all.filter_map do |mission|
        goal, target = mission["objetivo"].first
        value = count(goal)
        reached = goal == "vitorias_seguidas" ? value.positive? && (value % target).zero? : value >= target
        complete(mission, period(mission, match), match) if reached
      end
    end

    private

    def done = @done ||= @user.mission_completions.pluck(:mission, :period)

    def period(mission, match)
      case mission["repete"]
      when "semanal" then Date.current.strftime("%G-W%V")
      when "sempre" then "match-#{match&.id}"
      else ONCE
      end
    end

    def complete(mission, period, match)
      return if done.include?([ mission["id"], period ])

      card = prize(mission)
      @user.mission_completions.create!(mission: mission["id"], period:, card:, match:)
      CollectionCard.add!(@user, { card.id => 1 }) if card
      { name: mission["nome"], card: card&.name, packs: mission["libera_pacotes"].to_a }
    end

    # A carta da vez segue a lista, uma a cada vez que o jogador conclui (e recomeça no fim);
    # a outra é sorteada.
    def prize(mission)
      turn = mission.dig("premio", "carta_da_vez")
      name = turn ? turn[done.count { |id, _period| id == mission["id"] } % turn.size] : mission.dig("premio", "carta_sorteada_entre")&.sample(random: SecureRandom)
      Card.find_by!(name:) if name
    end

    def reward_text(mission)
      return "Libera #{mission['libera_pacotes'].to_sentence(two_words_connector: ' e ', last_word_connector: ' e ')} na loja" if mission["libera_pacotes"]
      return "Dá a carta da vez, uma por semana" if mission.dig("premio", "carta_da_vez")

      "Dá uma carta sorteada entre #{mission.dig('premio', 'carta_sorteada_entre').to_sentence(two_words_connector: ' e ', last_word_connector: ' e ')}"
    end

    def count(goal)
      today = Date.current
      case goal
      when "vitorias" then wins.size
      when "vitorias_no_mesmo_domingo" then today.sunday? ? wins.count { |time| time.to_date == today } : 0
      when "vitorias_na_semana" then wins.count { |time| time >= Time.current.beginning_of_week }
      else streak
      end
    end

    # Quando o jogador venceu cada duelo que conta, no fuso do jogo.
    def wins
      @wins ||= MatchPlayer.where(user_id: @user.id, mission_win: true).joins(:match).pluck("matches.finished_at").map(&:in_time_zone)
    end

    # As vitórias que contam desde a última partida que ele não venceu (a vitória que não
    # conta não quebra nem soma).
    def streak
      rows = MatchPlayer.where(user_id: @user.id).joins(:match).where(matches: { status: "finished" })
                        .order("matches.finished_at DESC, matches.id DESC").limit(STREAK_LOOKBACK).pluck(:mission_win, :team, "matches.winner_team")
      rows.take_while { |counts, team, winner| counts || winner == team }.count(&:first)
    end
  end
end
