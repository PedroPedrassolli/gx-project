# O que o jogador vê de cada carta (GXP-25), como a página da carta na Yugipedia mostra:
# tipo, atributo, raça, nível, ATK, DEF e o texto em inglês e em português.
class AddDetailsToCards < ActiveRecord::Migration[8.1]
  def change
    change_table :cards, bulk: true do |t|
      t.string :name_pt # nome em português, quando a carta saiu em português
      t.string :card_type # Monster, Spell ou Trap
      t.string :property # da magia ou armadilha: Normal, Continuous, Quick-Play...
      t.string :card_attribute # do monstro: DARK, LIGHT... ("attribute" é nome reservado no Rails)
      t.string :race # do monstro: Fiend, Warrior...
      t.string :monster_types, array: true, null: false, default: [] # Effect, Fusion, Tuner...
      t.integer :level
      t.integer :attack # ATK "?" fica sem valor
      t.integer :defense
      t.text :text # em inglês
      t.text :text_pt
    end
  end
end
