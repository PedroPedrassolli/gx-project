namespace :engine do
  desc "Confere se o script de cada carta do pool existe e carrega na engine (a CI roda no container)"
  task conferir: :environment do
    codes = GameData::Pool.codes(Rails.root.join("db/seeds/jogo"))
    # Carta Normal não tem script; as outras precisam ter.
    missing = codes.reject do |code|
      Duel::Engine.scripts.read("c#{code}.lua") || Duel::Engine.cards.find(code)&.type.to_i.anybits?(GameData::Coverage::NORMAL_MONSTER)
    end
    # Carrega todas na engine de uma vez: script que pede outro que não está aqui dá erro.
    half = codes.size / 2
    engine = Duel::Engine.new(seed: [ 1, 2, 3, 4 ], decks: [ { main: codes.first(half) }, { main: codes.drop(half) } ],
                              destiny_draw: false).start
    engine.advance
    errors = engine.errors
    engine.close
    puts "#{codes.size} cartas do pool; #{missing.size} sem script; #{errors.size} erros ao carregar."
    abort "Sem script: #{missing.first(20).join(', ')}. Erros: #{errors.first(5).join(' | ')}" if missing.any? || errors.any?
  end
end
