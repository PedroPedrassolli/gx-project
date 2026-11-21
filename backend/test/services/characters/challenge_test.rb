require "test_helper"

class Characters::ChallengeTest < ActiveSupport::TestCase
  include StarterDeckCards
  include CharacterCards

  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "Jaden", age_group: "18+") }
  let(:deck) do
    load_starter_deck_cards
    Decks::StarterDeck.give_to(user)
    user.decks.sole
  end
  let(:chumley) { Characters::Roster.find("chumley") }

  def challenge(character = chumley, with: deck) = Characters::Challenge.new(user, character, with).call

  it "começa o duelo sem sala, sem relógio e sem banlist, com o deck do personagem no lugar do computador" do
    load_character_cards("chumley")
    match = challenge
    player = match.players.find_by!(user:)
    bot = match.bot

    assert_equal [ nil, nil, nil, false, true ], [ match.room, match.decision_seconds, match.duel_minutes, match.banlist, match.destiny_draw ]
    assert_equal [ "chumley", nil, 45 ], [ bot.character, bot.user_id, bot.deck["main"].size + bot.deck["extra"].size ]
    assert_equal player.team, match.prompt_team
    assert_equal Card.where(name: "Master of Oz").pick(:engine_code), bot.deck["extra"].first
  end

  it "recusa o personagem ainda bloqueado" do
    error = assert_raises(Characters::Challenge::Refused) { challenge(Characters::Roster.find("syrus")) }

    assert_equal "Vença Chumley para liberar Syrus.", error.message
  end

  it "recusa quem já está num duelo ou numa sala" do
    load_character_cards("chumley")
    challenge

    assert_raises(Characters::Challenge::Refused) { challenge }
    Match.update_all(status: "finished")
    Room.create!(owner: user, code: "ABC234").players.create!(user:, seat: 0)
    assert_equal "Saia da sala para duelar contra um personagem.", assert_raises(Characters::Challenge::Refused) { challenge }.message
  end

  it "recusa o deck que não vale, mesmo sem banlist" do
    deck.deck_cards.where(section: "main").limit(10).destroy_all

    assert_match "Esse deck não vale: O Main Deck precisa ter de 40 a 60 cartas", assert_raises(Characters::Challenge::Refused) { challenge }.message
  end
end
