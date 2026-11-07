ENV["RAILS_ENV"] ||= "test"

# A cobertura começa antes de carregar o app, senão os arquivos já lidos ficam de fora.
require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  minimum_coverage line: 100
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter
  ])
end

require_relative "../config/environment"
require "rails/test_help"
require "minitest/spec"
require "mocha/minitest"

# Apoio dos testes (ex.: os bots que jogam duelos inteiros na engine).
Rails.root.glob("test/support/**/*.rb").each { |file| require file }

module ActiveSupport
  class TestCase
    # describe/it/let/subject do Minitest::Spec dentro das classes de teste do Rails.
    extend Minitest::Spec::DSL

    # Um processo só: a suíte leva cerca de 1 s, e com processos paralelos (fork) o Rails
    # precisa de um banco por processo e a cobertura precisa ser juntada no fim. Com mais
    # de 50 testes, o paralelo travou antes de começar (07/11/2026).
    parallelize(workers: 1)

    fixtures :all
  end
end
