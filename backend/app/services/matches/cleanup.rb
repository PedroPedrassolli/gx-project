module Matches
  # O replay fica 30 dias (escopo 3.7): depois disso, a partida acabada sai do banco, com os
  # jogadores e as respostas. Roda quando um duelo começa, de pouco em pouco, sem processo
  # agendado.
  class Cleanup
    KEEP = 30.days
    BATCH = 20

    # Quantas partidas saíram.
    def self.call(now = Time.current)
      Match.where(status: "finished", finished_at: ...(now - KEEP)).limit(BATCH).destroy_all.size
    end
  end
end
