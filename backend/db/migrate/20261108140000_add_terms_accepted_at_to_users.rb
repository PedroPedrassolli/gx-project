# Quando o jogador aceitou os termos de uso e a política de privacidade no cadastro
# (GXP-40). A versão aceita é a que valia nesse dia.
class AddTermsAcceptedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :terms_accepted_at, :datetime
  end
end
