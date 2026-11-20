module Shop
  # O código secreto da loja (escopo 3.4; GXP-89): quem digita o código de um pacote (a regra
  # "codigo" do disponibilidade.yml) passa a ver esse pacote na prateleira.
  module Code
    module_function

    # Os espaços não contam: "↑ ↑ ↓" e "↑↑↓" são o mesmo código.
    def normalize(code) = code.to_s.gsub(/\s+/, "")

    # Guarda o código para o jogador e devolve os nomes dos pacotes que ele libera (nenhum, se
    # o código não existe).
    def redeem(user, code)
      code = normalize(code)
      packs = Pack.order(:position).pluck(:name, :availability).filter_map { |name, rule| name if codes(rule).include?(code) }
      user.code_unlocks.create_or_find_by!(code:) if packs.any?
      packs
    end

    # Os códigos que liberam um pacote (a regra pode ser "qualquer uma destas").
    def codes(rule)
      (rule["regras"] || [ rule ]).filter_map { |each| normalize(each["codigo"]) if each["regra"] == "codigo" }
    end
  end
end
