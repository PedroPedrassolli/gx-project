module Economy
  # O anti-farm (escopo 3.5; ADR 0005 item 5), aplicado depois dos bônus e antes do crédito.
  # Devolve o total e os cortes, cada um com o motivo que a tela mostra. Sem banco nem relógio:
  # quem chama conta os duelos e o DP do dia.
  module AntiFarm
    # Duelo com menos de 3 turnos ou de 2 minutos paga só a derrota.
    SHORT_TURNS = 3
    SHORT_TIME = 2.minutes
    SHORT_DP = 10
    # Contra o mesmo oponente no mesmo dia: o 1º paga tudo, o 2º metade, o 3º um quarto.
    SAME_OPPONENT = [ 1, 0.5, 0.25, 0 ].freeze
    # As vitórias contra o mesmo oponente no dia que contam para missão: as que ainda pagam DP.
    MISSION_WINS = 3
    # Teto diário do DP vindo de duelos, pela metade nas contas com menos de 7 dias.
    DAILY_CAP = 3_000
    NEW_ACCOUNT = 7.days

    module_function

    # short: o duelo foi curto; earlier_today: quantos duelos contra o mesmo oponente já
    # acabaram hoje; earned_today: o DP de duelos que já entrou hoje; new_account: a conta tem
    # menos de 7 dias.
    def apply(subtotal, short:, earlier_today:, earned_today:, new_account:)
      cuts = []
      total = subtotal
      cut = lambda do |key, label, value|
        cuts << { key:, label:, dp: value - total } if value < total
        total = [ value, total ].min
      end
      cut.call("short", "Duelo curto (menos de #{SHORT_TURNS} turnos ou de #{SHORT_TIME.in_minutes.to_i} minutos): só a derrota", SHORT_DP) if short
      factor = SAME_OPPONENT[[ earlier_today, SAME_OPPONENT.size - 1 ].min]
      cut.call("same_opponent", "#{earlier_today + 1}º duelo contra o mesmo oponente hoje", (total * factor).floor)
      cap = new_account ? DAILY_CAP / 2 : DAILY_CAP
      cut.call("daily_cap", "Teto de #{cap.to_fs(:delimited, delimiter: '.')} DP por dia em duelos", [ cap - earned_today, 0 ].max)
      { total:, cuts: }
    end
  end
end
