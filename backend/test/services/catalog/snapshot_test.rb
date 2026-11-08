require "test_helper"

# Classe do Rails (e não describe solto) para ter transação por teste e travel.
class Catalog::SnapshotTest < ActiveSupport::TestCase
  include CatalogFixture

  before { load_catalog }

  it "guarda o catálogo por 5 minutos e depois relê do banco" do
    first = Catalog::Snapshot.current
    Card.find_by!(engine_code: 200).update!(name: "Trap Hole Renamed")

    _(Catalog::Snapshot.current).must_be_same_as first
    travel 6.minutes do
      _(Catalog::Snapshot.current).wont_be_same_as first
      _(Catalog::Snapshot.current.search(q: "renamed").pluck(:name)).must_equal [ "Trap Hole Renamed" ]
      _(Catalog::Snapshot.current.version).wont_equal first.version
    end
  end
end
