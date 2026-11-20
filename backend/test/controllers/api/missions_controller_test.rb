require "test_helper"

class Api::MissionsControllerTest < ActionDispatch::IntegrationTest
  it "lista as missões com o progresso do jogador; sem login, nada" do
    get api_missions_path
    assert_equal 401, response.status

    user = User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "18+")
    post api_session_path, params: { email: user.email, password: "duelista123" }, as: :json
    get api_missions_path

    first = response.parsed_body["data"].first
    assert_equal 6, response.parsed_body["data"].size
    assert_equal({ "id" => "torneio_slifer_red", "name" => "Torneio Slifer Red", "goal" => "Vencer 10 duelos", "progress" => 0, "target" => 10,
                   "done" => false, "repeats" => false, "reward" => "Libera Test of Luck e Power of the Heroes na loja" }, first)
  end
end
