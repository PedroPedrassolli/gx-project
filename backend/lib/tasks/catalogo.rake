namespace :catalogo do
  desc "Grava no banco o catálogo dos YAML de db/seeds/jogo (pode rodar de novo)"
  task importar: :environment do
    puts Catalog::Importer.new.run
  end
end
