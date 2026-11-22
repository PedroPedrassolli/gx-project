# A loja (escopo 3.4; GXP-86): a prateleira do jogador, a compra de pacotes, o código
# secreto e o conversor de cartas.
class Api::ShopController < Api::BaseController
  MAX_CODE = 64

  before_action :require_authentication

  rescue_from Economy::Ledger::InsufficientBalance do
    render_error(:unprocessable_content, "DP insuficiente para esta compra.")
  end

  rescue_from Shop::Purchase::Unavailable, Shop::Converter::Invalid do |error|
    render_error(:unprocessable_content, error.message)
  end

  # GET /api/shop: o saldo, o nível e os pacotes na ordem da loja, com a dica de como liberar
  # os bloqueados. new: liberado e ainda não visto na prateleira (POST /api/shop/seen).
  def show
    seen = current_user.seen_pack_ids.to_set
    packs = shelf.map do |pack, state|
      pack.slice(:id, :name, :price, :cards_per_pack).merge(state, new: state[:available] && !seen.include?(pack.id))
    end
    render json: { data: { balance: Economy::Ledger.balance(current_user), level: current_user.level, packs: } }
  end

  # POST /api/shop/seen: os pacotes liberados agora deixam de aparecer como novos.
  def seen
    available = shelf.filter_map { |pack, state| pack.id if state[:available] }
    current_user.update!(seen_pack_ids: current_user.seen_pack_ids | available)
    head :no_content
  end

  # POST /api/shop/purchases: { pack_id, count (1 ou 10), key }. A mesma chave devolve a mesma
  # compra, sem cobrar de novo.
  def purchase
    count = integer_param(params[:count])
    key = params[:key].to_s
    unless Shop::Purchase::COUNTS.include?(count) && key.match?(/\A[\w-]{8,64}\z/)
      return render_error(:unprocessable_content, "Compre 1 ou 10 pacotes.")
    end

    openings = Shop::Purchase.new(current_user, Pack.find(params[:pack_id].to_s), count:, key:).call
    render json: { data: { balance: Economy::Ledger.balance(current_user), openings: openings.map(&:cards) } }, status: :created
  end

  # POST /api/shop/codes: { code }. O código secreto que libera um pacote. A resposta de erro é
  # a mesma para qualquer código que não existe, e as tentativas têm limite (Rack::Attack).
  def code
    packs = Shop::Code.redeem(current_user, params[:code].to_s.first(MAX_CODE))
    return render_error(:unprocessable_content, "Esse código não libera nada.") if packs.empty?

    render json: { data: { packs: } }, status: :created
  end

  # GET /api/shop/converter: as cópias que o jogador pode converter, carta por carta.
  def converter
    cards = Shop::Converter.spare(current_user).map { |card_id, quantity| { card_id:, quantity: } }
    render json: { data: { min: Shop::Converter::RANGE.min, max: Shop::Converter::RANGE.max, cards: } }
  end

  # GET /api/shop/converter/groups/:amount: as cartas que podem sair com essa quantidade.
  def converter_group
    group = ConverterGroup.find_by!(amount: params[:amount].to_i)
    render json: { data: { amount: group.amount, cards: group.cards.order(:id).ids } }
  end

  # POST /api/shop/conversions: { cards: [{ id, quantity }], key }. A mesma chave devolve a
  # mesma conversão, sem gastar as cartas de novo.
  def conversion
    key = params[:key].to_s
    return render_error(:unprocessable_content, "Pedido inválido.") unless key.match?(/\A[\w-]{8,64}\z/)

    rows = params.permit(:key, cards: %i[id quantity]).fetch(:cards, nil)
    cards = Array(rows).each_with_object(Hash.new(0)) { |row, sum| sum[row[:id].to_i] += row[:quantity].to_i }
    conversion = Shop::Converter.new(current_user, cards, key:).call
    render json: { data: { card_id: conversion.card_id, amount: conversion.amount, new: conversion.new_card } }, status: :created
  end

  private

  # Os pacotes na ordem da loja, cada um com { available, hint } para o jogador.
  def shelf
    availability = Shop::Availability.for(current_user)
    Pack.order(:position).map { |pack| [ pack, availability.call(pack.availability) ] }
  end
end
