# Sem melhor de 3, o Side Deck perdeu o uso (GXP-125): as linhas de Side saem dos decks. As
# cartas continuam na coleção do jogador, porque o deck só aponta para elas.
class RemoveSideDeck < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM deck_cards WHERE section = 'side'"
  end

  def down = raise(ActiveRecord::IrreversibleMigration)
end
