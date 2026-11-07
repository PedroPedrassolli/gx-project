require "test_helper"

class Duel::EngineCacheTest < ActiveSupport::TestCase
  # Engine de mentira: o cache só precisa saber fechar.
  FakeEngine = Struct.new(:closed) do
    def close
      self.closed = true
    end
  end

  let(:cache) { Duel::EngineCache.new(2) }
  let(:engine) { FakeEngine.new(false) }

  describe "#take" do
    it "entrega a engine da mesma versão e tira ela do cache" do
      cache.put("duelo-1", "v1", engine)
      assert_equal [ engine, nil ], [ cache.take("duelo-1", "v1"), cache.take("duelo-1", "v1") ]
    end

    it "fecha e descarta a engine de outra versão" do
      cache.put("duelo-1", "v1", engine)
      assert_equal [ nil, true ], [ cache.take("duelo-1", "v2"), engine.closed ]
    end

    it "devolve nil para duelo que não está no cache" do
      assert_nil cache.take("duelo-9", "v1")
    end
  end

  describe "#put" do
    it "fecha a engine usada há mais tempo quando passa do limite" do
      cache.put("duelo-1", "v1", engine)
      cache.put("duelo-2", "v1", FakeEngine.new(false))
      cache.put("duelo-3", "v1", FakeEngine.new(false))
      assert_equal [ true, 2 ], [ engine.closed, cache.size ]
    end

    it "conta como uso recente a engine que saiu e voltou" do
      cache.put("duelo-1", "v1", engine)
      cache.put("duelo-2", "v1", FakeEngine.new(false))
      cache.put("duelo-1", "v2", cache.take("duelo-1", "v1"))
      cache.put("duelo-3", "v1", FakeEngine.new(false))
      assert_equal [ nil, engine ], [ cache.take("duelo-2", "v1"), cache.take("duelo-1", "v2") ]
    end

    it "fecha a engine antiga do mesmo duelo" do
      cache.put("duelo-1", "v1", engine)
      cache.put("duelo-1", "v2", FakeEngine.new(false))
      assert engine.closed
    end

    it "não fecha a engine que é guardada de novo" do
      2.times { cache.put("duelo-1", "v1", engine) }
      assert_equal [ false, engine ], [ engine.closed, cache.take("duelo-1", "v1") ]
    end
  end
end
