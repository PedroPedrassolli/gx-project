# Uma resposta dada à engine, na ordem (seq): com a semente e os decks, refaz o duelo.
class MatchResponse < ApplicationRecord
  belongs_to :match
end
