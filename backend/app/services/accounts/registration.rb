module Accounts
  # Cadastro (escopo 3.1; ADR 0008). Da data de nascimento só sai a faixa de idade: a data
  # não é guardada. Sem o aceite dos termos e da política de privacidade, não há conta.
  class Registration
    attr_reader :user

    # params: e-mail, senha, apelido, data de nascimento e o aceite, como vieram do formulário.
    def initialize(params)
      @user = User.new(email: params[:email], password: params[:password].to_s, nickname: params[:nickname])
      @birth_date = params[:birth_date]
      @terms_accepted = ActiveModel::Type::Boolean.new.cast(params[:terms_accepted])
    end

    # true quando cria a conta; senão, os erros de cada campo ficam em user.errors.
    def save
      date = parse(@birth_date)
      user.age_group = AgeGroup.for(date) if date
      user.terms_accepted_at = Time.current if @terms_accepted
      user.validate
      # O erro de faixa vira erro na data, que é o campo que a pessoa preencheu.
      user.errors.delete(:age_group)
      user.errors.add(:birth_date, birth_date_error(date)) unless user.age_group
      user.errors.add(:terms, I18n.t("accounts.terms.required")) unless @terms_accepted
      return false if user.errors.any?

      # Conta nova já ganha o deck inicial do jogo (escopo 3.2): tudo ou nada.
      User.transaction do
        user.save!
        Decks::StarterDeck.give_to(user)
      end
      # Se o e-mail falhar, a conta fica criada: dá para pedir de novo depois.
      Mailing.deliver(AccountMailer.email_verification(user))
      true
    rescue ActiveRecord::RecordNotUnique
      # Outro cadastro com o mesmo e-mail ou apelido entrou no mesmo instante: validar de
      # novo mostra qual dos dois já está em uso.
      user.validate
      false
    end

    private

    # A mensagem vai pronta: o User não tem o campo da data para o Rails montar sozinho.
    def birth_date_error(date)
      I18n.t(date ? :too_young : :invalid, scope: "accounts.birth_date")
    end

    # A data vem no formato do campo de data do navegador: AAAA-MM-DD.
    def parse(text)
      Date.iso8601(text.to_s)
    rescue Date::Error, ArgumentError # ArgumentError: texto longo demais para ser data
      nil
    end
  end
end
