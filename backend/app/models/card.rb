# Carta do pool. A chave é o código que a engine usa: o passcode, o da versão pré-errata
# ou o do script não oficial das cartas do anime (db/seeds/jogo/cobertura.yml).
class Card < ApplicationRecord
  has_many :pack_cards, dependent: :destroy
  has_many :packs, through: :pack_cards
  has_many :banlist_entries, dependent: :destroy
  has_many :converter_group_cards, dependent: :destroy
end
