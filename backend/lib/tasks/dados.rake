namespace :dados do
  desc "Baixa da Yugipedia os dados do jogo de referência para db/seeds/jogo (uns 3 minutos)"
  task jogo: :environment do
    export = GameData::Export.new(GameData::Yugipedia.new)
    directory = Rails.root.join("db/seeds/jogo")
    FileUtils.mkdir_p(directory)
    export.files.each { |name, content| File.write(directory.join(name), content) }
    puts export.checks
  end
end
