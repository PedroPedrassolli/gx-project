require "test_helper"

# As nossas traduções (db/seeds/jogo/traducoes.yml, ADR 0014) conferidas com o catálogo de
# verdade, dentro da transação do teste: toda carta do pool fica com texto em português e
# nenhuma tradução sobra. Se o `dados:jogo` mudar o inglês de uma carta, a tradução dela para
# de valer e este teste aponta qual refazer.
class Catalog::TranslationsTest < ActiveSupport::TestCase
  it "dá texto em português a toda carta do pool, oficial ou nosso, e usa toda tradução nossa" do
    Catalog::Importer.new.run

    _(Card.where(text_pt: nil).pluck(:name)).must_be_empty
    _(Card.where(text_pt_unofficial: true).count).must_equal YAML.safe_load_file(Rails.root.join("db/seeds/jogo/traducoes.yml")).size
  end
end
