# Código da imagem de cada carta no projeto de imagens do Cloudflare Pages (GXP-26): o
# passcode da carta impressa. Carta do anime sem impressão fica sem imagem.
class AddImageCodeToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :image_code, :integer
  end
end
