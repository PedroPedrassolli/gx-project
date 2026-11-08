# Conta de jogador (escopo 3.1; ADR 0008).
class User < ApplicationRecord
  AGE_GROUPS = %w[13-17 18+].freeze
  ROLES = %w[player admin].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :nickname, with: ->(nickname) { nickname.strip }

  validates :email, presence: true
  validates :email, uniqueness: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :nickname, presence: true
  validates :nickname, length: { in: 3..20 }, format: { with: /\A[A-Za-z0-9_-]+\z/ }, uniqueness: { case_sensitive: false }, allow_blank: true
  validates :age_group, inclusion: { in: AGE_GROUPS }
  validates :role, inclusion: { in: ROLES }
  validate :nickname_must_be_clean

  # O que a API mostra do usuário: nunca a senha.
  def as_json(*) = { id:, email:, nickname:, age_group:, role: }

  private

  def nickname_must_be_clean
    errors.add(:nickname, :offensive) if nickname.present? && !Accounts::NicknameFilter.clean?(nickname)
  end
end
