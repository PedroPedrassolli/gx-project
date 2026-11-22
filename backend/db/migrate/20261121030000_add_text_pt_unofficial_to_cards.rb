# Quando a carta não tem texto oficial em português, ela mostra a nossa tradução
# (db/seeds/jogo/traducoes.yml, GXP-106), e a tela avisa que não é a oficial.
class AddTextPtUnofficialToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :text_pt_unofficial, :boolean, null: false, default: false
  end
end
