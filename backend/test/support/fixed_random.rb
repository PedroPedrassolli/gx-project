# Um "acaso" que não sorteia, para testar as escolhas do computador e do robô: rand sem limite
# devolve o valor dado; com limite (número ou intervalo), o primeiro valor possível.
class FixedRandom
  def initialize(value) = @value = value

  def rand(limit = nil)
    case limit
    when nil then @value
    when Range then limit.first
    else 0
    end
  end
end
