# Sala de duelo (escopo 3.6; ADR 0010): as opções, o dono e quem está em cada lugar. A
# pública aparece na lista; na privada só entra quem tem o código de 6 caracteres.
class Room < ApplicationRecord
  # Sem 0/O e 1/I: o código é lido em voz alta ou copiado à mão.
  CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".chars.freeze
  CODE_LENGTH = 6
  # Lugares por modo (o Tag, com 4, vem na F6).
  SEATS = { "1x1" => 2 }.freeze
  # Sala parada há mais que isso sai da lista: ninguém entra numa sala esquecida.
  LISTED_FOR = 1.hour

  belongs_to :owner, class_name: "User"
  has_many :players, -> { order(:seat) }, class_name: "RoomPlayer", inverse_of: :room, dependent: :delete_all

  scope :listed, -> { where(public: true, status: "waiting", updated_at: LISTED_FOR.ago..) }

  validates :code, presence: true, uniqueness: true
  validates :mode, inclusion: { in: SEATS.keys }
  validates :best_of, inclusion: { in: [ 1 ] }
  validates :status, inclusion: { in: %w[waiting dueling] }

  def self.new_code = Array.new(CODE_LENGTH) { CODE_CHARS.sample(random: SecureRandom) }.join

  def seats = SEATS.fetch(mode)

  def waiting? = status == "waiting"

  def free_seat = ((0...seats).to_a - players.map(&:seat)).first
end
