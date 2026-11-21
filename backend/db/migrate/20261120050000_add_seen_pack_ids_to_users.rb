# Destaque de pacote "Novo" na loja (escopo 4; GXP-42): os pacotes liberados que o jogador já
# viu na prateleira. O que está liberado e não está aqui aparece como novo.
class AddSeenPackIdsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :seen_pack_ids, :bigint, array: true, null: false, default: []
  end
end
