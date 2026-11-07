require "test_helper"

class Duel::ScriptLibraryTest < ActiveSupport::TestCase
  subject { Duel::ScriptLibrary.default }

  describe "#read" do
    it "acha os scripts da raiz" do
      assert_match(/Duel/, subject.read("utility.lua"))
    end

    it "acha o script de uma carta de efeito" do
      assert_match(/c26202165|s,id/, subject.read("c26202165.lua")) # Sangan
    end

    it "devolve nil para carta sem script (monstro Normal)" do
      assert_nil subject.read("c46986414.lua")
    end

    it "guarda o conteúdo depois da primeira leitura" do
      first = subject.read("constant.lua")
      assert_same first, subject.read("./constant.lua")
    end
  end
end
