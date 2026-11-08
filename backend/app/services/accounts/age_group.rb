module Accounts
  # Faixa de idade a partir da data de nascimento (escopo 3.1; ADR 0008). Só a faixa fica
  # guardada: a data serve para o cadastro e é descartada.
  module AgeGroup
    MINIMUM_AGE = 13
    ADULT_AGE = 18

    module_function

    # "13-17", "18+" ou nil (menos de 13 anos, ou data no futuro). O dia de hoje é o de
    # São Paulo (config.time_zone).
    def for(birth_date, today: Time.zone.today)
      age = age_on(birth_date, today)
      return if age < MINIMUM_AGE

      age < ADULT_AGE ? "13-17" : "18+"
    end

    # Anos completos no dia: um a menos se o aniversário do ano ainda não chegou. Quem
    # nasceu em 29 de fevereiro faz aniversário em 1º de março nos outros anos.
    def age_on(birth_date, today)
      had_birthday = today.month > birth_date.month ||
        (today.month == birth_date.month && today.day >= birth_date.day)
      today.year - birth_date.year - (had_birthday ? 0 : 1)
    end
  end
end
