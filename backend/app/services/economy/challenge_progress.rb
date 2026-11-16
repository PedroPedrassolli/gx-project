module Economy
  # Marca os desafios que um jogador concluiu no duelo que acabou (GXP-88): monta o que se sabe
  # do duelo e do deck dele, pergunta a Economy::Challenges e grava os que ele ainda não tinha.
  class ChallengeProgress
    def initialize(match)
      @match = match
    end

    # stats: o mesmo Hash que vai para os bônus (Economy::DuelRewards). Devolve os números
    # dos desafios novos e quantos o jogador tem agora.
    def complete(player, user, stats)
      had = user.user_challenges.pluck(:number)
      new_numbers = Challenges.completed(facts(player, stats)) - had
      new_numbers.each { |number| user.user_challenges.create!(number:, match: @match) }
      { new: new_numbers, total: had.size + new_numbers.size }
    end

    private

    # Vitória e empate só valem os da engine: desistência e tempo não concluem desafio.
    def facts(player, stats)
      main, extra = deck_cards(player)
      by_engine = stats[:engine_win]
      Challenges::Facts.new(won: by_engine && stats[:result] == :win, draw: by_engine && stats[:result] == :draw, counts: stats[:duel],
                            main:, extra:, restricted:, **stats.slice(:turns, :opponent_turn, :win_reason, :summoned, :used, :finisher))
    end

    # As cartas do deck que o jogador usou (a partida guarda os códigos da engine), com as cópias.
    def deck_cards(player)
      lists = player.deck.values_at("main", "extra")
      cards = Card.where(engine_code: lists.flatten.uniq).index_by(&:engine_code)
      lists.map { |codes| cards.values_at(*codes).compact }
    end

    # Os ids das cartas proibidas, limitadas ou semilimitadas na banlist do jogo.
    def restricted
      @restricted ||= BanlistEntry.joins(:banlist).where(banlists: { name: Catalog::Importer::DEFAULT_BANLIST }).pluck(:card_id).to_set
    end
  end
end
