require "test_helper"

# Garante que o Bullet continua ligado nos testes de API: uma consulta por deck (N+1)
# precisa derrubar a requisição.
class BulletTest < ActionDispatch::IntegrationTest
  class DecksWithNPlusOneController < ActionController::API
    def index
      Deck.all.each { |deck| deck.deck_cards.to_a }
      head :ok
    end
  end

  it "acusa consulta N+1 numa requisição" do
    user = User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "13-17")
    2.times { |number| user.decks.create!(name: "Deck #{number}") }

    with_routing do |routes|
      routes.draw { get "/n_plus_one" => "bullet_test/decks_with_n_plus_one#index" }
      error = assert_raises(Bullet::Notification::UnoptimizedQueryError) { get "/n_plus_one" }
      assert_match "USE eager loading", error.message
    end
  end
end
