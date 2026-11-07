require "test_helper"

class Realtime::MemoryPublisherTest < ActiveSupport::TestCase
  subject { Realtime::MemoryPublisher.new }

  describe "#publish" do
    before do
      subject.publish(user_id: 1, event: "duel.delta", data: { seq: 1 })
      subject.publish(user_id: 2, event: "duel.delta", data: { seq: 1 })
      subject.publish(user_id: 1, event: "duel.ended", data: { winner: 0 })
    end

    it "entrega cada evento só no canal do jogador, na ordem" do
      assert_equal [ "duel.delta", "duel.ended" ], subject.events_for(1).map(&:name)
    end

    it "guarda o canal e os dados do evento" do
      event = subject.events_for(2).first
      assert_equal [ "private:user:2", { seq: 1 } ], [ event.channel, event.data ]
    end

    it "esvazia com #clear" do
      subject.clear
      assert_empty subject.events_for(1)
    end
  end
end
