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
      [ 1, Duel::Query::BANISHED ] => [ { code: 9, position: 0x1, public: true }, { code: 10, position: 0xA, public: false } ],
      [ 0, Duel::Query::SPELLS ] => [ { code: 15, position: 0xA }, { code: 16, position: 0x5 } ],
      [ 0, Duel::Query::HAND ] => [ { code: 11, public: true }, { code: 12, public: false } ],
      [ 1, Duel::Query::HAND ] => [ { code: 13, public: true }, { code: 14, public: false } ]
    }
    fake = Object.new
    fake.define_singleton_method(:query_field) { [ { lp: 8000, deck: 30, extra: 0 }, { lp: 7000, deck: 31, extra: 0 } ] }
    fake.define_singleton_method(:query_location) { |team, location| cards.fetch([ team, location ], []) }
    mine, theirs = Duel::View.new(fake, 0).sides

    assert_equal({ face_down: true, defense: true, code: 5, atk: 1000, def: 900 }, mine[:monsters].first)
    assert_equal [ nil, { face_down: true, defense: true }, { face_down: false, defense: false, code: 7, atk: 800, def: 600 } ], theirs[:monsters]
    assert_equal [ [ { code: 8 } ], [ { code: 9 }, { hidden: true } ] ], theirs.values_at(:grave, :banished)
    # Magia e armadilha não ficam "em defesa", mesmo com o bit de defesa na posição.
    assert_equal [ [ true, false ], [ false, false ] ], mine[:spells].first(2).map { |card| card.values_at(:face_down, :defense) }
    # Na mão, o outro só vê a carta revelada; o dono vê todas e sabe quais estão à vista.
    assert_equal [ { code: 11, public: true }, { code: 12 } ], mine[:hand]
    assert_equal [ { code: 13 }, { hidden: true } ], theirs[:hand]
  end

  it "a pergunta traz o texto de cada descrição (efeitos e opções da carta e o Destiny Draw)" do
    painful = 74191942 << 20
    view = ->(prompt) { Duel::View.new(engine, 0).to_h(**state, prompt:)[:prompt] }

    options = view.call({ type: :select_option, player: 0, options: [ painful, painful | 1 ] })
    assert_equal [ "Select 5 cards from your Deck", "Select 1 card to add to your opponent's hand" ], options[:options_text]
    assert_equal "Usar o Destiny Draw?", view.call({ type: :select_yesno, player: 0, description: Duel::Engine::DESTINY_DRAW_QUESTION })[:text]
    chain = view.call({ type: :select_chain, player: 0, chains: [ { code: 74191942, controller: 0, location: 2, sequence: 0, description: painful | 1 } ] })
    assert_equal "Select 1 card to add to your opponent's hand", chain[:chains].first[:text]
    assert_nil view.call({ type: :select_yesno, player: 0, description: 30 })[:text]
  end

  it "esconde também as cartas obrigatórias da soma; o número anunciado não vira texto" do
    hidden = { code: 11, controller: 1, location: Duel::Query::HAND, sequence: 0, sum: 4 }
    view = ->(prompt) { Duel::View.new(engine, 0).to_h(**state, prompt:)[:prompt] }

    assert_equal [ 0 ], view.call({ type: :select_sum, player: 0, must: [ hidden ], cards: [] })[:must].pluck(:code)
    assert_not view.call({ type: :announce_number, player: 0, options: [ 1 << 20 ] }).key?(:options_text)
  end

  it "a dica do que escolher traz o texto quando é de uma carta" do
    view = ->(hint) { Duel::View.new(engine, 0).to_h(**state, prompt: { type: :select_card, player: 0, hint:, cards: [] })[:prompt] }

    assert_equal "Select 1 card to add to your opponent's hand", view.call((74191942 << 20) | 1)[:hint_text]
    assert_nil view.call(502)[:hint_text]
  end

  it "os eventos chegam com o que cada lado vê e a corrente com o texto de cada efeito" do
    painful = 74191942 << 20
    events = [ { type: "draw", team: 0, codes: [ 11 ] } ]
    chain = [ { code: 74191942, controller: 0, location: 8, sequence: 0, position: 1, description: painful | 1, link: 1 } ]
    view = ->(viewer) { Duel::View.new(engine, viewer).to_h(**state, prompt: nil, events:, chain:) }

    assert_equal [ { type: "draw", team: 0, count: 1 } ], view.call(1)[:events]
    assert_equal events, view.call(0)[:events]
    assert_equal "Select 1 card to add to your opponent's hand", view.call(1)[:chain].first[:text]
  end

  it "todas as etapas da batalha aparecem como battle" do
    assert_equal %w[battle battle end], [ 0x08, 0x40, 0x200 ].map { |phase| Duel::View.new(engine, 0).to_h(**state, phase:, prompt: nil)[:phase] }
  end

  it "manda junto o resumo das cartas à vista que o catálogo não tem, como as fichas" do
    Card.create!(engine_code: 46986414, name: "Dark Magician", source_revision: 1)
    Catalog::Snapshot.reset!
    # A ficha está virada para baixo: o outro não vê o código, nem o resumo.
    monsters = [ { code: 46986414, position: 0x1, atk: 2500, def: 2100 }, { code: 46173680, position: 0x8, atk: 0, def: 0 } ]
    fake = Object.new
    fake.define_singleton_method(:query_field) { [ { lp: 8000, deck: 30, extra: 0 }, { lp: 8000, deck: 30, extra: 0 } ] }
    fake.define_singleton_method(:query_location) { |team, location| team.zero? && location == Duel::Query::MONSTERS ? monsters : [] }
    # A carta comprada vem em "codes"; a do outro, virada, chega com o código 0.
    events = [ { type: "draw", team: 0, codes: [ 33900648 ] }, { type: "set", controller: 1, code: 0, location: 0x4, sequence: 0 } ]
    view = Duel::View.new(fake, 0).to_h(**state, prompt: nil, events:)

    _(view[:cards].keys).must_equal [ 46173680, 33900648 ]
    _(view[:cards][46173680]).must_equal Duel::CardSummary.call(46173680)
    _(Duel::View.new(fake, 1).to_h(**state, prompt: nil, events: [])).wont_include :cards
    Catalog::Snapshot.reset!
  end
end
