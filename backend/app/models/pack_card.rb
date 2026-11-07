# Carta de um pacote, com a raridade em que ela sai nele.
class PackCard < ApplicationRecord
  belongs_to :pack
  belongs_to :card

  enum :rarity, { common: "common", rare: "rare", super_rare: "super_rare", ultra_rare: "ultra_rare" }, validate: true
end
