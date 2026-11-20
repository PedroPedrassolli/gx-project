# Um código secreto que o jogador já digitou na loja (libera o pacote que pede esse código).
class CodeUnlock < ApplicationRecord
  belongs_to :user
end
