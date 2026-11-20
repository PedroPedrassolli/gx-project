# A loja (escopo 3.4; GXP-86): a prateleira do jogador e a compra de pacotes.
class Api::ShopController < Api::BaseController
  MAX_CODE = 64

  before_action :require_authentication

  rescue_from Economy::Ledger::InsufficientBalance do
    render_error(:unprocessable_content, "DP insuficiente para esta compra.")
  end

  rescue_from Shop::Purchase::Unavailable do |error|
    render_error(:unprocessable_content, error.message)
  end

  # GET /api/shop: o saldo, o nível e os pacotes na ordem da loja, com a dica de como liberar
  # os bloqueados.
  def show
    availability = Shop::Availability.for(current_user)
    packs = Pack.order(:position).map do |pack|
      pack.slice(:id, :name, :price, :cards_per_pack).merge(availability.call(pack.availability))
    end
    render json: { data: { balance: Economy::Ledger.balance(current_user), level: current_user.level, packs: } }
  end

  # POST /api/shop/purchases: { pack_id, count (1 ou 10), key }. A mesma chave devolve a mesma
  # compra, sem cobrar de novo.
  def purchase
    count = params[:count].to_i
    key = params[:key].to_s
    unless Shop::Purchase::COUNTS.include?(count) && key.match?(/\A[\w-]{8,64}\z/)
      return render_error(:unprocessable_content, "Compre 1 ou 10 pacotes.")
    end

    openings = Shop::Purchase.new(current_user, Pack.find(params[:pack_id]), count:, key:).call
    render json: { data: { balance: Economy::Ledger.balance(current_user), openings: openings.map(&:cards) } }, status: :created
  end

  # POST /api/shop/codes: { code }. O código secreto que libera um pacote. A resposta de erro é
  # a mesma para qualquer código que não existe, e as tentativas têm limite (Rack::Attack).
  def code
    packs = Shop::Code.redeem(current_user, params[:code].to_s.first(MAX_CODE))
    return render_error(:unprocessable_content, "Esse código não libera nada.") if packs.empty?

    render json: { data: { packs: } }, status: :created
  end
end
