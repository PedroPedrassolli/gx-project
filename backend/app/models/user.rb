# Conta de jogador (escopo 3.1; ADR 0008).
class User < ApplicationRecord
  AGE_GROUPS = %w[13-17 18+].freeze
  ROLES = %w[player admin].freeze

  # O link de troca de senha vale 1 hora (ADR 0008).
  has_secure_password reset_token: { expires_in: 1.hour }
  # O link de confirmação vale 2 dias e deixa de valer se o e-mail mudar.
  generates_token_for :email_verification, expires_in: 2.days do
    email
  end
  has_many :sessions, dependent: :destroy
  has_many :collection_cards, dependent: :delete_all
  has_many :decks, dependent: :destroy

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
  def as_json(*) = { id:, email:, email_verified: email_verified_at.present?, nickname:, age_group:, role: }

  private

  def nickname_must_be_clean
    errors.add(:nickname, :offensive) if nickname.present? && !Accounts::NicknameFilter.clean?(nickname)
  end
end
