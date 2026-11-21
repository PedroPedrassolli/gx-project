namespace :banco do
  desc "Fecha a API de dados do Supabase: RLS em toda tabela e nada para anon e authenticated"
  task fechar_api: :environment do
    opened = Supabase::Lockdown.new.call
    if opened.empty?
      puts "Nenhuma tabela estava aberta para a API de dados."
    else
      tables = opened.size == 1 ? "1 tabela que estava aberta" : "#{opened.size} tabelas que estavam abertas"
      puts "RLS ligado em #{tables}: #{opened.join(', ')}."
    end
  end
end
