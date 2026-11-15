module Economy
  # O DP do fim do duelo (GXP-85; ADR 0005): para cada jogador com conta, os bônus, o
  # anti-farm, o crédito no razão (chave partida:ID, então nunca paga duas vezes) e a subida de
  # nível, que paga 400 por nível. O resumo fica no jogador da partida, para a tela de
  # resultado. Roda na mesma transação que encerra a partida.
  class DuelRewards
    LEVEL_UP_DP = 400
    ZONE = "America/Sao_Paulo"

    # field: a mesa no fim (Duel::Query.field), com o PV e o deck de cada lado.
    def initialize(match, field)
      @match = match
      @field = field
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
      lines = BonusCalculator.lines(stats(player, user, opponent))
      farm = AntiFarm.apply(lines.sum { |line| line[:dp] }, short: short?, earlier_today: earlier_today(user, opponent),
                                                             earned_today: earned_today(user), new_account: user.created_at > AntiFarm::NEW_ACCOUNT.ago)
      Ledger.post!(user, farm[:total], reason: "duel", key: "partida:#{@match.id}", ref: @match)
      level_ups = level_up(user.reload)
      player.update!(rewards: { lines:, cuts: farm[:cuts], level_ups:, total: farm[:total] + level_ups.sum { |line| line[:dp] },
                                level: user.level, balance: Ledger.balance(user) })
    end

    def stats(player, user, opponent)
      side = @field[player.team]
      result = if @match.winner_team.nil? then :draw elsif @match.winner_team == player.team then :win else :loss end
      { result:, turns: @match.turn, level: user.level, opponent_level: opponent&.level || 1,
        engine_win: @match.finish_reason == "duel", win_reason: @match.win_reason, lp: side[:lp], deck: side[:deck],
        opponent_turn: @match.turn_team != player.team }
    end

    def short? = @match.turn < AntiFarm::SHORT_TURNS || (@match.finished_at - @match.started_at) < AntiFarm::SHORT_TIME

    def today = Time.current.in_time_zone(ZONE).all_day

    # Duelos contra o mesmo oponente que já acabaram hoje (sem contar este).
    def earlier_today(user, opponent)
      return 0 unless opponent

      Match.where(status: "finished", finished_at: today).where.not(id: @match.id)
           .where(id: MatchPlayer.where(user_id: user.id).select(:match_id))
           .where(id: MatchPlayer.where(user_id: opponent.id).select(:match_id)).count
    end

    def earned_today(user) = user.dp_transactions.where(reason: "duel", created_at: today).sum(:amount)

    # Cada nível novo paga 400, e esse DP também conta para o próximo nível.
    def level_up(user)
      lines = []
      while (level = Level.for(user.dp_earned)) > user.level
        dp = LEVEL_UP_DP * (level - user.level)
        user.update!(level:)
        Ledger.post!(user, dp, reason: "level_up", key: "nivel:#{level}", ref: @match)
        lines << { key: "level_up", label: "Subiu para o nível #{level}", dp: }
        user.reload
      end
      lines
    end
  end
end
