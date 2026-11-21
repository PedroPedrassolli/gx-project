module Characters
  # A vitória contra um personagem (escopo 3.10; ADR 0013): conta mais uma e, na primeira, dá a
  # carta-símbolo (vai para a coleção, uma vez só) e libera o próximo da lista. O que aconteceu
  # entra no resumo do fim do duelo (rewards), para a tela de resultado. Roda na mesma
  # transação que encerra a partida, depois do DP (Economy::DuelRewards).
  class Victory
    def initialize(match)
      @match = match
    end

    def call
      bot = @match.bot
      player = @match.players.find { |item| item != bot }
      character = Roster.find(bot&.character)
      return unless character && player.user_id && @match.winner_team == player.team

      win = CharacterWin.create_or_find_by!(user_id: player.user_id, character: character.id)
      win.increment!(:wins)
      player.update!(rewards: player.rewards.to_h.merge(first_win(player, character))) if win.wins == 1
    end

    private

    def first_win(player, character)
      card = Card.find_by!(name: character.signature)
      CollectionCard.add!(player.user, { card.id => 1 })
      after = Roster.after(character)
      { card: { id: card.id, name: card.name, name_pt: card.name_pt, image: card.image_code }.compact,
        unlocked: ({ id: after.id, name: after.name } if after) }.compact
    end
  end
end
