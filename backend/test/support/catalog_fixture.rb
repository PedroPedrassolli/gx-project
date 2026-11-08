# Carrega no banco de teste o catálogo pequeno de test/fixtures/files/catalogo (5 cartas,
# 4 pacotes e a banlist) e limpa o catálogo da memória da API.
module CatalogFixture
  def load_catalog
    Catalog::Importer.new(Rails.root.join("test/fixtures/files/catalogo")).run
    Catalog::Snapshot.reset!
  end
end
