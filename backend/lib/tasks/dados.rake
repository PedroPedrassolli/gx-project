namespace :dados do
  desc "Baixa da Yugipedia os dados do jogo de referência para db/seeds/jogo (uns 3 minutos)"
  task jogo: :environment do
    export = GameData::Export.new(GameData::Yugipedia.new)
    directory = Rails.root.join("db/seeds/jogo")
    FileUtils.mkdir_p(directory)
    export.files.each { |name, content| File.write(directory.join(name), content) }
    puts export.checks
  end

  desc "Cruza o pool com os scripts e o BabelCDB da engine e com as imagens do YGOPRODeck"
  task cobertura: :environment do
    require "sqlite3"
    require "net/http"
    engine = Rails.root.join("vendor/engine")
    database = { "cards.cdb" => false, "cards-unofficial.cdb" => true }.flat_map do |file, unofficial|
      SQLite3::Database.new(engine.join("BabelCDB", file).to_s, readonly: true)
        .execute("SELECT d.id, d.alias, d.type, t.name FROM datas d JOIN texts t ON t.id = d.id")
        .map { |id, aka, type, name| { id:, alias: aka, type:, name:, unofficial: } }
    end
    scripts = %w[official pre-errata unofficial].index_with do |folder|
      engine.glob("CardScripts/#{folder}/c*.lua").to_set { |path| path.basename.to_s[/\d+/].to_i }
    end
    # Uma chamada só, com a lista inteira do YGOPRODeck (uns 25 MB).
    body = Net::HTTP.get(URI("https://db.ygoprodeck.com/api/v7/cardinfo.php"),
                         "User-Agent" => GameData::Yugipedia::USER_AGENT)
    images = JSON.parse(body)["data"].flat_map { |card| card["card_images"].pluck("id") }.to_set

    cards = YAML.safe_load_file(Rails.root.join("db/seeds/jogo/cartas.yml"))
    coverage = GameData::Coverage.new(cards:, database:, scripts:, images:)
    File.write(Rails.root.join("db/seeds/jogo/cobertura.yml"), coverage.file)
    puts coverage.summary
  end
end
