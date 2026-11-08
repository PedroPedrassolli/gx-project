require "test_helper"

class Accounts::NicknameFilterTest < ActiveSupport::TestCase
  def clean?(nickname) = Accounts::NicknameFilter.clean?(nickname)

  it "aceita apelidos comuns, mesmo com pedaço parecido com palavrão" do
    %w[Pedrassolli Ana_Lima CanalDuelista Paulo xX_Dark_Xx Assassino JadenYuki Piranha].each do |nickname|
      _(clean?(nickname)).must_equal true, nickname
    end
  end

  it "barra palavrão de 5 letras ou mais em qualquer parte do apelido" do
    %w[caralhoX Mestre_Porra MotherFucker99].each do |nickname|
      _(clean?(nickname)).must_equal false, nickname
    end
  end

  it "barra palavrão curto só quando ele é uma palavra separada" do
    %w[Fuck_you puta-123 FDP BigFuckBoss].each do |nickname|
      _(clean?(nickname)).must_equal false, nickname
    end
  end

  it "lê número no lugar de letra" do
    %w[p0rra C4ralho].each do |nickname|
      _(clean?(nickname)).must_equal false, nickname
    end
  end

  it "barra palavrão soletrado com separadores" do
    _(clean?("F_U_C_K")).must_equal false
  end
end
