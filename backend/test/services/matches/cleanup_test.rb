require "test_helper"

class Matches::CleanupTest < ActiveSupport::TestCase
  def match(status:, days_ago:)
    Match.create!(mode: "1x1", banlist: true, destiny_draw: false, seed: [ 1, 2, 3, 4 ], status:, started_at: days_ago.days.ago,
                  finished_at: (days_ago.days.ago if status == "finished")).tap do |match|
      match.players.create!(team: 0, seat: 0, deck: { main: [], extra: [] })
      match.responses.create!(seq: 0, team: 0, bytes: "x")
    end
  end

  it "tira do banco as partidas acabadas há mais de 30 dias, com jogadores e respostas" do
    old = match(status: "finished", days_ago: 31)
    recent = match(status: "finished", days_ago: 29)
    dueling = match(status: "dueling", days_ago: 40)

    assert_equal 1, Matches::Cleanup.call
    assert_equal [ recent.id, dueling.id ].sort, Match.pluck(:id).sort
    assert_equal [ 0, 0 ], [ MatchPlayer.where(match_id: old.id).count, MatchResponse.where(match_id: old.id).count ]
  end
end
