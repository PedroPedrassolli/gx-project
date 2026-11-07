require "test_helper"
require "open3"

# Teste de contrato: os números que o Ruby usa precisam bater com o header da engine
# fixada no submódulo. Quando a engine for atualizada, este teste avisa o que mudou.
# Compila um programinha em C++ que imprime cada constante (precisa do g++).
class Duel::ConstantsTest < ActiveSupport::TestCase
  EXPECTED = {
    "DUEL_MODE_MR1" => Duel::Engine::MODE_MR1,
    "OCG_DUEL_STATUS_END" => Duel::Engine::STATUS_END,
    "OCG_DUEL_STATUS_CONTINUE" => Duel::Engine::STATUS_CONTINUE,
    "OCG_LOG_TYPE_ERROR" => Duel::Engine::LOG_ERROR,
    "LOCATION_DECK" => Duel::Engine::LOCATION_DECK,
    "LOCATION_EXTRA" => Duel::Engine::LOCATION_EXTRA,
    "POS_FACEDOWN_DEFENSE" => Duel::Engine::POS_FACEDOWN_DEFENSE,
    "TYPE_LINK" => Duel::CardDatabase::TYPE_LINK,
    "MSG_RETRY" => Duel::MessageParser::RETRY,
    "MSG_WIN" => Duel::MessageParser::WIN,
    "MSG_NEW_TURN" => Duel::MessageParser::NEW_TURN
  }.merge(Duel::MessageParser::PROMPTS.to_h { |value, name| [ "MSG_#{name.upcase}", value ] }).freeze

  subject { values_from_header(EXPECTED.keys) }

  it "os valores do Ruby batem com os do header da engine" do
    assert_equal EXPECTED, subject
  end

  private

  def values_from_header(names)
    source = +"#include <cstdio>\n#include \"ocgapi_types.h\"\n#include \"ocgapi_constants.h\"\nint main() {\n"
    names.each { |name| source << %(  printf("#{name} %llu\\n", (unsigned long long)(#{name}));\n) }
    source << "  return 0;\n}\n"
    Dir.mktmpdir do |dir|
      binary = File.join(dir, "constants")
      header_dir = Rails.root.join("vendor/engine/ygopro-core").to_s
      _out, error, status = Open3.capture3("g++", "-std=c++17", "-w", "-I#{header_dir}", "-x", "c++", "-", "-o", binary,
                                           stdin_data: source)
      raise "o programa das constantes não compilou: #{error}" unless status.success?

      Open3.capture2(binary).first.lines.to_h { |line| line.split.then { |name, value| [ name, Integer(value) ] } }
    end
  end
end
