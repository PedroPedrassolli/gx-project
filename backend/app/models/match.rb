# Partida: o duelo de uma sala (ADR 0011). O time 0 começa.
class Match < ApplicationRecord
  belongs_to :room, optional: true
  has_many :players, -> { order(:team) }, class_name: "MatchPlayer", inverse_of: :match, dependent: :delete_all
  has_many :responses, -> { order(:seq) }, class_name: "MatchResponse", inverse_of: :match, dependent: :delete_all

  validates :status, inclusion: { in: %w[dueling finished] }

  # O duelo em andamento de um jogador (pela vaga dele na sala), ou nil.
  def self.current_for(user) = includes(:room).joins(room: :players).find_by(status: "dueling", room_players: { user_id: user.id })

  def dueling? = status == "dueling"
end
