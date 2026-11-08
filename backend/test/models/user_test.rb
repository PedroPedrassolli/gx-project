require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build_user(**attributes)
    User.new(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "13-17", **attributes)
  end

  # Mensagens de erro de um campo, depois de validar.
  def errors_on(user, attribute)
    user.validate
    user.errors[attribute]
  end

  it "é válido com e-mail, senha, apelido e faixa de idade" do
    user = build_user

    _(user).must_be :valid?
    _(user.role).must_equal "player"
  end

  it "guarda o e-mail sem espaços e em minúsculas, e não repete" do
    build_user(email: "  Jaden@Example.COM ").save!

    _(User.last.email).must_equal "jaden@example.com"
    _(errors_on(build_user(nickname: "Outro"), :email)).must_include "já está em uso"
  end

  it "recusa e-mail inválido" do
    _(errors_on(build_user(email: "jaden"), :email)).must_include "não é válido"
  end

  it "pede senha de 8 caracteres ou mais" do
    _(errors_on(build_user(password: "1234567"), :password)).must_include "é curta demais (mínimo de 8 caracteres)"
  end

  it "recusa senha com mais de 72 bytes, o limite do bcrypt" do
    _(errors_on(build_user(password: "a" * 73), :password)).must_include "é longa demais (máximo de 72 bytes)"
  end

  it "pede apelido de 3 a 20 caracteres, só com letras sem acento, números, _ e -" do
    _(errors_on(build_user(nickname: "Jo"), :nickname)).must_include "é curto demais (mínimo de 3 caracteres)"
    _(errors_on(build_user(nickname: "J" * 21), :nickname)).must_include "é longo demais (máximo de 20 caracteres)"
    _(errors_on(build_user(nickname: "João"), :nickname)).must_include "só aceita letras sem acento, números, _ e -"
  end

  it "não repete apelido, nem com outras maiúsculas" do
    build_user.save!

    _(errors_on(build_user(email: "outro@example.com", nickname: "jadenyuki"), :nickname)).must_include "já está em uso"
  end

  it "recusa apelido com palavrão" do
    _(errors_on(build_user(nickname: "Mestre_Porra"), :nickname)).must_include "não é permitido"
  end

  it "só aceita as faixas de idade e os papéis conhecidos" do
    _(errors_on(build_user(age_group: "10-12"), :age_group)).must_include "não está na lista"
    _(errors_on(build_user(role: "dono"), :role)).must_include "não está na lista"
  end

  it "apaga as sessões junto com a conta" do
    user = build_user
    user.save!
    user.sessions.create!

    assert_difference("Session.count", -1) { user.destroy }
  end
end
