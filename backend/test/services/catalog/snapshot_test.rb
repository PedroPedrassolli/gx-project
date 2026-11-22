require "test_helper"

# Classe do Rails (e não describe solto) para ter transação por teste e travel.
class Catalog::SnapshotTest < ActiveSupport::TestCase
  include CatalogFixture

  before { load_catalog }

  it "sem mudança no banco, fica com o mesmo catálogo, por mais tempo que passe" do
    first = Catalog::Snapshot.current

    travel 2.hours do
      _(Catalog::Snapshot.current).must_be_same_as first
    end
  end

  it "remonta quando o banco muda, conferindo no máximo a cada 30 s" do
    first = Catalog::Snapshot.current
    travel 1.second
    Card.find_by!(engine_code: 200).update!(name: "Trap Hole Renamed")

    _(Catalog::Snapshot.current).must_be_same_as first
    travel 31.seconds do
      _(Catalog::Snapshot.current).wont_be_same_as first
      _(Catalog::Snapshot.current.search(q: "renamed").pluck(:name)).must_equal [ "Trap Hole Renamed" ]
      _(Catalog::Snapshot.current.version).wont_equal first.version
    end
  end

  it "as linhas dos pacotes, que toda importação regrava, também contam como mudança" do
    first = Catalog::Snapshot.current
    travel 1.minute do
      PackCard.first.touch

      _(Catalog::Snapshot.current).wont_be_same_as first
    end
  end

  it "o aquecimento monta o catálogo antes do primeiro pedido, e um erro só vai para o log" do
    Catalog::Snapshot.warm_up
    _(Catalog::Snapshot.instance_variable_get(:@current)).must_be_kind_of Catalog::Snapshot

    Catalog::Snapshot.reset!
    Catalog::Snapshot.stubs(:stamp).raises(ActiveRecord::ConnectionNotEstablished, "sem banco")
    Rails.logger.expects(:warn).with("O catálogo não aqueceu: ActiveRecord::ConnectionNotEstablished: sem banco")
    Catalog::Snapshot.warm_up
    _(Catalog::Snapshot.instance_variable_get(:@current)).must_be_nil
  end
end
