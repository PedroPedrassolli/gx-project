# Partida: o duelo de uma sala (ADR 0011) ou contra um personagem (ADR 0013). O time 0 começa.
class Match < ApplicationRecord
  belongs_to :room, optional: true
  has_many :players, -> { order(:team) }, class_name: "MatchPlayer", inverse_of: :match, dependent: :delete_all
  has_many :responses, -> { order(:seq) }, class_name: "MatchResponse", inverse_of: :match, dependent: :delete_all

  validates :status, inclusion: { in: %w[dueling finished] }

  # O duelo em andamento de um jogador (pela vaga dele na sala ou contra um personagem), ou nil.
  def self.current_for(user)
    includes(:room).joins(room: :players).find_by(status: "dueling", room_players: { user_id: user.id }) || against_character(user)
  end

  # O duelo contra personagem em andamento de um jogador (sem sala), ou nil.
  def self.against_character(user) = joins(:players).find_by(status: "dueling", room_id: nil, match_players: { user_id: user.id })

  def dueling? = status == "dueling"

  # O lugar do computador, no duelo contra personagem (nil no duelo entre jogadores).
  def bot = players.find { |player| player.character.present? }

  # Quando o duelo acaba pelo relógio; nil quando o dono da sala escolheu sem limite.
  def ends_at = duel_minutes && started_at + duel_minutes.minutes
end
