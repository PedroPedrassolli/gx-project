namespace :e2e do
  desc "Banco de teste para o duelo de ponta a ponta (GXP-57): o catálogo e dois jogadores com o deck inicial"
  task preparar: :environment do
    abort "Só no banco de teste (RAILS_ENV=test)." unless Rails.env.test?

    Catalog::Importer.new.run
    %w[Jaden Syrus].each do |name|
      user = User.find_or_initialize_by(email: "#{name.downcase}@example.com")
      next if user.persisted?

      user.update!(password: "duelista123", nickname: name, age_group: "18+", terms_accepted_at: Time.current,
                   email_verified_at: Time.current)
      Decks::StarterDeck.give_to(user)
    end
    puts "Pronto: jaden@example.com e syrus@example.com, senha duelista123."
  end
end
