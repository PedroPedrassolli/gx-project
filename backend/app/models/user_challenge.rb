# Um desafio concluído por um jogador (os desafios em si estão em Economy::Challenges).
class UserChallenge < ApplicationRecord
  belongs_to :user
  belongs_to :match, optional: true
end
