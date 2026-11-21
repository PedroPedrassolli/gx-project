# Carta nova no baú do Deck Edit (GXP-42): a carta que o jogador ganhou e ainda não viu fica
# com seen_at vazio. As que já estavam na coleção contam como vistas.
class AddSeenAtToCollectionCards < ActiveRecord::Migration[8.1]
  def up
    add_column :collection_cards, :seen_at, :datetime
    execute "UPDATE collection_cards SET seen_at = obtained_at"
  end

  def down
    remove_column :collection_cards, :seen_at
  end
end
