# Carta do pool. A chave é o código que a engine usa: o passcode, o da versão pré-errata
# ou o do script não oficial das cartas do anime (db/seeds/jogo/cobertura.yml). Guarda
# também o que o jogador vê, como a Yugipedia escreve: tipo (Monster, Spell, Trap),
# atributo, raça, nível, ATK, DEF e o texto em inglês e em português.
class Card < ApplicationRecord
  has_many :pack_cards, dependent: :destroy
  has_many :packs, through: :pack_cards
  has_many :banlist_entries, dependent: :destroy
  has_many :converter_group_cards, dependent: :destroy
end
