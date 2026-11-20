require "test_helper"

# Roda no banco de teste, dentro da transação do teste: o RLS, o papel criado aqui e os
# privilégios voltam ao que eram no fim de cada teste.
class Supabase::LockdownTest < ActiveSupport::TestCase
  let(:connection) { ActiveRecord::Base.connection }
  # Um papel que faz as vezes do anon do Supabase.
  let(:role) { "gx_api_#{Process.pid}" }

  def allowed?(table)
    connection.select_value("SELECT has_table_privilege(#{connection.quote(role)}, #{connection.quote(table)}, 'SELECT')")
  end

  it "liga o RLS em toda tabela do public e devolve as que estavam abertas" do
    lockdown = Supabase::Lockdown.new
    assert_includes lockdown.open_tables, "users"

    opened = lockdown.call

    assert_includes opened, "users"
    assert_includes opened, "schema_migrations"
    assert_empty lockdown.open_tables
    assert connection.select_value("SELECT relrowsecurity FROM pg_class WHERE oid = 'users'::regclass")
    assert_empty Supabase::Lockdown.new.call, "na segunda vez não sobra nada para fechar"
  end

  it "tira os privilégios dos papéis da API, nas tabelas de hoje e nas que vierem" do
    connection.execute("CREATE ROLE #{role} NOLOGIN")
    connection.execute("GRANT SELECT ON users TO #{role}")
    connection.execute("ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO #{role}")
    assert allowed?("users")

    Supabase::Lockdown.new(roles: [ role, "papel_que_nao_existe" ]).call
    connection.execute("CREATE TABLE gx_lockdown_nova (id bigint)")

    assert_not allowed?("users")
    assert_not allowed?("gx_lockdown_nova")
  end

  it "com o RLS ligado, o dono da tabela lê e grava, e os outros papéis não veem nada" do
    owner = "gx_dono_#{Process.pid}"
    connection.execute("CREATE ROLE #{owner} NOLOGIN")
    connection.execute("CREATE ROLE #{role} NOLOGIN")
    connection.execute("CREATE TABLE gx_lockdown_dono (id bigint)")
    connection.execute("ALTER TABLE gx_lockdown_dono OWNER TO #{owner}")
    connection.execute("GRANT SELECT ON gx_lockdown_dono TO #{role}")

    Supabase::Lockdown.new.call

    connection.execute("SET LOCAL ROLE #{owner}")
    connection.execute("INSERT INTO gx_lockdown_dono VALUES (1)")
    assert_equal 1, connection.select_value("SELECT count(*) FROM gx_lockdown_dono")
    connection.execute("SET LOCAL ROLE #{role}")
    assert_equal 0, connection.select_value("SELECT count(*) FROM gx_lockdown_dono")
  ensure
    connection.execute("RESET ROLE")
  end
end
