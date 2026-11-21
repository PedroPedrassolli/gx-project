module Economy
  # O anti-farm (escopo 3.5; ADR 0005 item 5), aplicado depois dos bônus e antes do crédito.
  # Devolve o total e os cortes, cada um com o motivo que a tela mostra. Sem banco nem relógio:
  # quem chama diz se o duelo foi curto e o DP de duelos do dia.
  #
  # O projeto é para jogar com a família e os amigos: em 20/11/2026 saíram o corte por jogar de
  # novo com a mesma pessoa no dia e a metade do teto nas contas novas. Ficam o duelo curto
  # (desistir logo não rende) e um teto do dia, só para segurar algum erro.
  module AntiFarm
    # Duelo com menos de 3 turnos ou de 2 minutos paga só 10.
    SHORT_TURNS = 3
    SHORT_TIME = 2.minutes
    SHORT_DP = 10
    # Teto diário do DP vindo de duelos (uns 15 duelos vencidos).
    DAILY_CAP = 15_000

    module_function

    def apply(subtotal, short:, earned_today:)
      cuts = []
      total = subtotal
      cut = lambda do |key, label, value|
        cuts << { key:, label:, dp: value - total } if value < total
        total = [ value, total ].min
      end
      cut.call("short", "Duelo curto (menos de #{SHORT_TURNS} turnos ou de #{SHORT_TIME.in_minutes.to_i} minutos)", SHORT_DP) if short
      cut.call("daily_cap", "Teto de #{DAILY_CAP.to_fs(:delimited, delimiter: '.')} DP por dia em duelos", [ DAILY_CAP - earned_today, 0 ].max)
      { total:, cuts: }
    end
  end
end
