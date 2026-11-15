# Um jogador sentado numa sala, com o deck escolhido e se está pronto. Cada jogador fica
# numa sala só por vez (índice único em user_id).
class RoomPlayer < ApplicationRecord
  # touch: entrar, sair ou ficar pronto conta como movimento da sala (Room::LISTED_FOR).
  belongs_to :room, touch: true
  belongs_to :user
  belongs_to :deck, optional: true
end
