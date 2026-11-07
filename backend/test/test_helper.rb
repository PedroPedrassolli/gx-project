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

module ActiveSupport
  class TestCase
    # describe/it/let/subject do Minitest::Spec dentro das classes de teste do Rails.
    extend Minitest::Spec::DSL

    parallelize(workers: :number_of_processors)

    # Cada processo grava a própria cobertura; o SimpleCov junta tudo no fim.
    parallelize_setup { |worker| SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}" }
    parallelize_teardown { |_worker| SimpleCov.result }

    fixtures :all
  end
end
