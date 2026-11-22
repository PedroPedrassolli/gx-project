module Characters
  # Até onde um jogador chegou na lista (escopo 3.10; ADR 0013): quantas vezes venceu cada
  # personagem e quais estão liberados. O primeiro sempre está; os outros, depois de vencer o
  # anterior.
  class Progress
    def initialize(user)
      @wins = user.character_wins.pluck(:character, :wins).to_h
    end

    def wins(character) = @wins.fetch(character.id, 0)

    def unlocked?(character)
      previous = Roster.before(character)
      previous.nil? || wins(previous).positive?
    end
  end
end
