require "test_helper"

class Accounts::AgeGroupTest < ActiveSupport::TestCase
  let(:today) { Date.new(2026, 11, 8) }

  it "recusa quem ainda não fez 13 anos" do
    _(Accounts::AgeGroup.for(Date.new(2013, 11, 9), today:)).must_be_nil
  end

  it "aceita no dia em que a pessoa faz 13 anos" do
    _(Accounts::AgeGroup.for(Date.new(2013, 11, 8), today:)).must_equal "13-17"
  end

  it "separa quem tem de 13 a 17 de quem tem 18 ou mais" do
    _(Accounts::AgeGroup.for(Date.new(2008, 11, 9), today:)).must_equal "13-17"
    _(Accounts::AgeGroup.for(Date.new(2008, 11, 8), today:)).must_equal "18+"
  end

  it "conta o aniversário de 29 de fevereiro a partir de 1º de março" do
    born = Date.new(2008, 2, 29)

    _(Accounts::AgeGroup.for(born, today: Date.new(2026, 2, 28))).must_equal "13-17"
    _(Accounts::AgeGroup.for(born, today: Date.new(2026, 3, 1))).must_equal "18+"
  end

  it "recusa data no futuro" do
    _(Accounts::AgeGroup.for(Date.new(2027, 1, 1), today:)).must_be_nil
  end

  it "usa o dia de hoje no fuso de São Paulo" do
    # 2h de 9/11 em UTC ainda é 23h de 8/11 em São Paulo: a pessoa não fez 13 anos.
    travel_to Time.utc(2026, 11, 9, 2) do
      _(Accounts::AgeGroup.for(Date.new(2013, 11, 9))).must_be_nil
    end
  end
end
