module Economy
  # O DP do fim do duelo (GXP-85; ADR 0005): para cada jogador com conta, os desafios que ele
  # concluiu, os bônus, o anti-farm, o crédito no razão (chave partida:ID, então nunca paga
  # duas vezes) e a subida de nível, que paga 100 por nível. O resumo fica no jogador da
  # partida, para a tela de resultado. Roda na mesma transação que encerra a partida.
  class DuelRewards
    LEVEL_UP_DP = 100
    ZONE = "America/Sao_Paulo"

    # field: a mesa no fim (Duel::Query.field), com o PV e o deck de cada lado.
    def initialize(match, field)
      @match = match
      @field = field
      @duel = Duel::Stats.new(match.stats)
      @challenges = ChallengeProgress.new(match)
    end

    def call
      players = @match.players.select(&:user_id)
      users = User.where(id: players.map(&:user_id)).index_by(&:id)
      players.each do |player|
        user = users[player.user_id]
        next unless user # a conta acabou de ser apagada

        opponent = players.find { |other| other.team != player.team }
        reward(player, user, opponent && users[opponent.user_id])
      end
    end

    private

    def reward(player, user, opponent)
      stats = stats(player, user, opponent)
      progress = @challenges.complete(player, user, stats)
      challenges = progress[:new].map { |number| { number:, label: Challenges.label(number) } }
      lines = BonusCalculator.lines(stats.merge(challenges: progress[:total]))
      farm = AntiFarm.apply(lines.sum { |line| line[:dp] }, short: short?, earned_today: earned_today(user))
      missions = missions(player, user, stats[:result] == :win && !short?)
      Ledger.post!(user, farm[:total], reason: "duel", key: "partida:#{@match.id}", ref: @match)
      level_ups = level_up(user.reload)
      player.update!(rewards: { lines:, cuts: farm[:cuts], level_ups:, challenges:, missions:, total: farm[:total] + level_ups.sum { |line| line[:dp] },
                                level: user.level, balance: Ledger.balance(user) })
    end

    def stats(player, user, opponent)
      side = @field[player.team]
      duel = @duel.team(player.team)
      result = if @match.winner_team.nil? then :draw elsif @match.winner_team == player.team then :win else :loss end
      { result:, turns: @match.turn, level: user.level, opponent_level: opponent&.level || 1,
        engine_win: @match.finish_reason == "duel", win_reason: @match.win_reason, lp: side[:lp], deck: side[:deck],
        opponent_turn: @match.turn_team != player.team, duel:, **card_names(duel) }
    end

    # A vitória que conta para missão fica marcada no jogador da partida, e as missões que
    # chegaram ao objetivo com ela são concluídas (Economy::Missions).
    def missions(player, user, counts)
      return [] unless counts

      player.update!(mission_win: true)
      Missions.new(user).award(@match)
    end

    # Os nomes das cartas que pagam bônus ou contam para desafio, entre as que o time invocou
    # e usou, e a do golpe final (as estatísticas guardam o código da engine).
    def card_names(duel)
      codes = [ *duel["summoned"], *duel["used"], duel["finisher"] ].compact
      watched = BonusCalculator::CARD_NAMES + Challenges::CARD_NAMES
      names = Card.where(engine_code: codes, name: watched).pluck(:engine_code, :name).to_h
      { summoned: names.values_at(*duel["summoned"]).compact, used: names.values_at(*duel["used"]).compact, finisher: names[duel["finisher"]] }
    end

    def short? = @match.turn < AntiFarm::SHORT_TURNS || (@match.finished_at - @match.started_at) < AntiFarm::SHORT_TIME

    def today = Time.current.in_time_zone(ZONE).all_day

    def earned_today(user) = user.dp_transactions.where(reason: "duel", created_at: today).sum(:amount)

    # Cada nível novo paga 100. Esse DP não conta para o próximo nível (Ledger), então uma
    # conta basta, mesmo quando o duelo sobe vários níveis de uma vez.
    def level_up(user)
      level = Level.for(user.dp_earned)
      return [] unless level > user.level

      dp = LEVEL_UP_DP * (level - user.level)
      user.update!(level:)
      Ledger.post!(user, dp, reason: "level_up", key: "nivel:#{level}", ref: @match)
      [ { key: "level_up", label: "Subiu para o nível #{level}", dp: } ]
    end
  end
end
