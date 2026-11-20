module Supabase
  # Fecha a API de dados do Supabase (REST e GraphQL) para as tabelas do Rails (GXP-92).
  #
  # O Supabase publica o schema public nessa API. Com a chave anon, que ele trata como
  # pública, dá para ler e gravar qualquer tabela que esteja sem RLS. O GX Project não usa
  # essa API: o Rails conecta direto no Postgres como dono das tabelas, e o dono não passa
  # pelo RLS. Então esta classe:
  #   1. liga o RLS, sem nenhuma política, em toda tabela do public: para os papéis da API,
  #      nenhuma linha aparece e nenhuma gravação passa;
  #   2. tira desses papéis os privilégios nas tabelas e sequências de hoje e nas que vierem.
  # Roda no workflow Banco de produção, depois das migrações (tarefa banco:fechar_api), e pode
  # rodar de novo quantas vezes for preciso.
  class Lockdown
    # Os papéis da API de dados. Só existem no Supabase: na CI e no computador, o passo 2 não
    # faz nada.
    API_ROLES = %w[anon authenticated].freeze

    def initialize(connection = ActiveRecord::Base.connection, roles: API_ROLES)
      @connection = connection
      @roles = roles
    end

    # Fecha tudo e devolve as tabelas que estavam sem RLS.
    def call
      opened = open_tables
      opened.each do |table|
        @connection.execute("ALTER TABLE #{@connection.quote_table_name(table)} ENABLE ROW LEVEL SECURITY")
      end
      revoke_privileges
      opened
    end

    # As tabelas do public sem RLS, em ordem alfabética.
    def open_tables
      @connection.select_values(<<~SQL)
        SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p') AND NOT c.relrowsecurity
        ORDER BY c.relname
      SQL
    end

    private

    # REVOKE nas tabelas e sequências que existem e ALTER DEFAULT PRIVILEGES nas que as
    # próximas migrações criarem (elas são criadas pelo mesmo usuário que roda esta tarefa).
    def revoke_privileges
      roles = existing_roles
      return if roles.empty?

      names = roles.map { |role| @connection.quote_column_name(role) }.join(", ")
      %w[TABLES SEQUENCES].each do |kind|
        @connection.execute("REVOKE ALL ON ALL #{kind} IN SCHEMA public FROM #{names}")
        @connection.execute("ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON #{kind} FROM #{names}")
      end
    end

    def existing_roles
      list = @roles.map { |role| @connection.quote(role) }.join(", ")
      @connection.select_values("SELECT rolname FROM pg_roles WHERE rolname IN (#{list}) ORDER BY rolname")
    end
  end
end
