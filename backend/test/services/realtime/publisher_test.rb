require "test_helper"

class Realtime::PublisherTest < ActiveSupport::TestCase
  describe ".channel_for" do
    it "dá o canal privado do jogador" do
      assert_equal "private:user:42", Realtime::Publisher.channel_for(42)
    end

    it "recusa id com curinga ou outros símbolos" do
      assert_raises(ArgumentError) { Realtime::Publisher.channel_for("*") }
    end
  end

  describe ".build" do
    it "usa o Ably quando tem a chave" do
      assert_instance_of Realtime::AblyPublisher, Realtime::Publisher.build("app.chave:segredo")
    end

    it "guarda na memória sem a chave (desenvolvimento e CI)" do
      assert_instance_of Realtime::MemoryPublisher, Realtime::Publisher.build(nil)
    end
  end

  describe ".current" do
    it "é sempre o mesmo publicador no processo" do
      assert_same Realtime::Publisher.current, Realtime::Publisher.current
    end
  end
end
