# Quando o jogador confirmou o e-mail pelo link (GXP-35); vazio até confirmar.
class AddEmailVerifiedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_verified_at, :datetime
  end
end
