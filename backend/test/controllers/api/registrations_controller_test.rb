require "test_helper"

class Api::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include StarterDeckCards

  before { load_starter_deck_cards }

  let(:form) do
    { email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", birth_date: "2010-05-01", terms_accepted: true }
  end

  def sign_up(**changes) = post(api_registrations_path, params: form.merge(changes), as: :json)
  def field_errors = response.parsed_body["error"]["fields"]

  it "cria a conta com a faixa de idade, já entra e manda o e-mail de confirmação" do
    travel_to Time.zone.local(2026, 11, 8) do
      assert_emails(1) { sign_up }
    end

    assert_response :created
    _(response.parsed_body["user"]).must_include "id"
    _(User.last.age_group).must_equal "13-17"
    _(User.last.terms_accepted_at).must_equal Time.zone.local(2026, 11, 8)
    _(User.last.sessions.count).must_equal 1
    _(User.last.decks.pluck(:name)).must_equal [ "Deck inicial" ]
    get api_session_path
    _(response.parsed_body["user"]["nickname"]).must_equal "JadenYuki"
  end

  it "não guarda a data de nascimento" do
    sign_up(birth_date: "1990-01-31")

    _(User.last.attributes.values.map(&:to_s).join).wont_include "1990"
  end

  it "recusa quem tem menos de 13 anos e não grava nada" do
    travel_to Time.zone.local(2026, 11, 8) do
      sign_up(birth_date: "2013-11-09")
    end

    assert_response :unprocessable_content
    _(field_errors["birth_date"]).must_equal [ "precisa ser de quem tem 13 anos ou mais" ]
    _(User.count).must_equal 0
  end

  it "devolve os erros de cada campo, em português" do
    sign_up(email: "jaden", password: "123", nickname: "Mestre_Porra", birth_date: "31/02/2010")

    assert_response :unprocessable_content
    _(response.parsed_body["error"]["message"]).must_equal "Confira os campos."
    _(field_errors).must_equal({ "email" => [ "não é válido" ], "password" => [ "é curta demais (mínimo de 8 caracteres)" ],
                                 "nickname" => [ "não é permitido" ], "birth_date" => [ "não é uma data válida" ] })
  end

  it "pede o aceite dos termos de uso e da política de privacidade" do
    sign_up(terms_accepted: nil)

    assert_response :unprocessable_content
    _(field_errors).must_equal({ "terms" => [ "aceite os termos de uso e a política de privacidade para criar a conta" ] })
    _(User.count).must_equal 0
  end

  it "senha que não é texto conta como senha inválida, sem quebrar" do
    sign_up(password: 12345)

    assert_response :unprocessable_content
    _(field_errors["password"]).must_equal [ "é curta demais (mínimo de 8 caracteres)" ]
  end

  it "data de nascimento longa demais é só uma data inválida" do
    sign_up(birth_date: "2" * 200)

    _(field_errors["birth_date"]).must_equal [ "não é uma data válida" ]
  end

  it "cadastro com o mesmo e-mail no mesmo instante responde 422, não 500" do
    User.any_instance.stubs(:save!).raises(ActiveRecord::RecordNotUnique)
    sign_up

    assert_response :unprocessable_content
    _(User.count).must_equal 0
  end

  it "pede a data de nascimento" do
    sign_up(birth_date: nil)

    _(field_errors["birth_date"]).must_equal [ "não é uma data válida" ]
  end
end
