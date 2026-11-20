require "test_helper"

class Shop::AvailabilityTest < ActiveSupport::TestCase
  def check(rule, level: 1, day: "terca", total: { owned: 30, cards: 100 }, packs: { "Pack A" => { owned: 1, cards: 4 } }, challenges: 7, **more)
    Shop::Availability.new(level:, day:, total:, packs:, challenges:, **more).call(rule)
  end

  it "sempre, nível e dia da semana (ou o nível que libera todo dia)" do
    assert_equal({ available: true, hint: nil }, check({ "regra" => "sempre" }))
    assert_equal({ available: false, hint: "Chegue ao nível 27." }, check({ "regra" => "nivel", "nivel" => 27 }))
    assert check({ "regra" => "nivel", "nivel" => 27 }, level: 27)[:available]

    monday = { "regra" => "dia", "dia" => "segunda", "nivel_libera" => 21 }
    assert_equal "Volte numa segunda ou chegue ao nível 21.", check(monday)[:hint]
    assert check(monday, day: "segunda")[:available]
    assert check(monday, level: 21)[:available]
  end

  it "porcentagem de um pacote e de todas as cartas, com quanto o jogador já tem" do
    pack = { "regra" => "porcentagem_de_pacote", "pacote" => "Pack A", "porcentagem" => 50 }
    assert_equal({ available: false, hint: "Tenha 50% das cartas de Pack A (você tem 25%)." }, check(pack))
    assert check(pack, packs: { "Pack A" => { owned: 2, cards: 4 } })[:available]

    total = { "regra" => "porcentagem_do_total", "porcentagem" => 60 }
    assert_equal "Tenha 60% de todas as cartas do jogo (você tem 30%).", check(total)[:hint]
  end

  it "todos os desafios: os que dá para concluir, com quantos o jogador já tem" do
    rule = { "regra" => "todos_os_desafios" }

    assert_equal({ available: false, hint: "Conclua todos os desafios (você tem 7 de 101)." }, check(rule))
    assert check(rule, challenges: 101)[:available]
  end

  it "missão: libera para quem concluiu; código: para quem já digitou, e a dica não mostra o código" do
    mission = { "regra" => "missao", "missao" => "torneio_slifer_red" }
    assert_equal({ available: false, hint: "Conclua a missão Torneio Slifer Red." }, check(mission))
    assert check(mission, missions: [ "torneio_slifer_red" ])[:available]

    code = { "regra" => "codigo", "codigo" => "↑ ↑ ↓ ↓" }
    assert_equal({ available: false, hint: "Digite o código secreto na loja." }, check(code))
    assert check(code, codes: [ "↑↑↓↓" ])[:available]
  end

  it "qualquer uma das regras libera, e a dica junta as que faltam" do
    any = { "regra" => "qualquer", "regras" => [ { "regra" => "porcentagem_do_total", "porcentagem" => 90 }, { "regra" => "todos_os_desafios" },
                                                { "regra" => "nivel", "nivel" => 50 } ] }
    assert_equal "Tenha 90% de todas as cartas do jogo (você tem 30%), ou conclua todos os desafios (você tem 7 de 101), ou chegue ao nível 50.",
                 check(any)[:hint]
    assert check(any, level: 50)[:available]
  end
end
