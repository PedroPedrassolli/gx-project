require "test_helper"

class Api::ChallengesControllerTest < ActionDispatch::IntegrationTest
  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "18+") }

  it "lista os 104 desafios com os que o jogador concluiu e os que ainda não dá para concluir" do
    user.user_challenges.create!(number: 26)
    post api_session_path, params: { email: user.email, password: "duelista123" }, as: :json
    get api_challenges_path

    data = response.parsed_body["data"]
    assert_equal [ 1, 104, 104 ], [ data["done"], data["total"], data["challenges"].size ]
    assert_equal({ "number" => 26, "label" => "Empatar um duelo", "done" => true, "possible" => true }, data["challenges"][25])
    assert_equal [ false, false ], data["challenges"][24].values_at("done", "possible")
  end

  it "sem login, nada" do
    get api_challenges_path

    assert_equal 401, response.status
  end
end
