require "test_helper"

class Duel::ViewTest < ActiveSupport::TestCase
  let(:recording) { Duel::HealthCheck.recording }
  let(:engine) { Duel::Engine.new(seed: recording[:seed], decks: recording[:decks]).start.tap(&:advance) }
  let(:state) { { turn: 1, turn_team: 0, phase: 0x04, prompt_team: 0 } }

  after { engine.close }

  it "mostra a própria mão e esconde a do outro; o deck é só a quantidade" do
    mine, theirs = Duel::View.new(engine, 0).to_h(**state, prompt: nil)[:sides]

    assert(mine[:hand].all? { |card| recording[:decks][0][:main].include?(card[:code]) })
    assert_equal [ { hidden: true } ] * theirs[:hand].size, theirs[:hand]
    assert_equal [ 8000, [ nil ] * 5, [ nil ] * 5 ], mine.values_at(:lp, :monsters, :spells)
    assert_equal recording[:decks][1][:main].size - theirs[:hand].size, theirs[:deck]
    assert_not theirs.key?(:extra_cards)
  end

  it "a pergunta só vai para quem responde, sem o código das cartas escondidas do outro" do
    prompt = { type: :select_card, player: 0, min: 1, max: 1,
               cards: [ { code: 11, controller: 1, location: Duel::Query::HAND, sequence: 0 },
                        { code: 22, controller: 1, location: Duel::Query::MONSTERS, sequence: 0, position: 0x8 },
                        { code: 33, controller: 1, location: Duel::Query::MONSTERS, sequence: 1, position: 0x1 },
                        { code: 44, controller: 0, location: Duel::Query::HAND, sequence: 0 } ] }

    view = Duel::View.new(engine, 0).to_h(**state, prompt:)
    assert_equal [ 0, 0, 33, 44 ], view[:prompt][:cards].pluck(:code)
    assert_equal [ "main1", 0 ], view.values_at(:phase, :waiting_for)
    assert_not Duel::View.new(engine, 1).to_h(**state, prompt:).key?(:prompt)
  end

  it "no campo, a carta virada do outro só mostra a posição; as próprias aparecem inteiras" do
    cards = {
      [ 0, Duel::Query::MONSTERS ] => [ { code: 5, position: 0x8, atk: 1000, def: 900 } ],
      [ 1, Duel::Query::MONSTERS ] => [ nil, { code: 6, position: 0x8, atk: 1200, def: 1100 }, { code: 7, position: 0x1, atk: 800, def: 600 } ],
      [ 1, Duel::Query::GRAVE ] => [ { code: 8, position: 0x1 } ],
      [ 1, Duel::Query::BANISHED ] => [ { code: 9, position: 0x1, public: true }, { code: 10, position: 0xA, public: false } ]
    }
    fake = Object.new
    fake.define_singleton_method(:query_field) { [ { lp: 8000, deck: 30, extra: 0 }, { lp: 7000, deck: 31, extra: 0 } ] }
    fake.define_singleton_method(:query_location) { |team, location| cards.fetch([ team, location ], []) }
    mine, theirs = Duel::View.new(fake, 0).sides

    assert_equal({ face_down: true, defense: true, code: 5, atk: 1000, def: 900 }, mine[:monsters].first)
    assert_equal [ nil, { face_down: true, defense: true }, { face_down: false, defense: false, code: 7, atk: 800, def: 600 } ], theirs[:monsters]
    assert_equal [ [ { code: 8 } ], [ { code: 9 }, { hidden: true } ] ], theirs.values_at(:grave, :banished)
  end

  it "todas as etapas da batalha aparecem como battle" do
    assert_equal %w[battle battle end], [ 0x08, 0x40, 0x200 ].map { |phase| Duel::View.new(engine, 0).to_h(**state, phase:, prompt: nil)[:phase] }
  end
end
