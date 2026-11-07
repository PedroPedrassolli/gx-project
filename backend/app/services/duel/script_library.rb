module Duel
  # Encontra os scripts Lua das cartas (CardScripts) e guarda o conteúdo em memória
  # depois da primeira leitura, para o replay não ir ao disco de novo.
  #
  # Cada script é procurado só quando a engine pede. Listar os 19 mil arquivos de uma vez
  # custava tempo no primeiro duelo de cada instância.
  class ScriptLibrary
    # A raiz tem constant.lua, utility.lua e os proc_*.lua; depois vêm as cartas.
    FOLDERS = [ "", "official", "pre-errata", "unofficial" ].freeze

    def self.default
      new(Rails.root.join("vendor/engine/CardScripts"))
    end

    def initialize(root)
      @root = root.to_s
      @contents = {}
      @mutex = Mutex.new
    end

    # Conteúdo do script, ou nil quando não existe (carta Normal não tem script, e tudo bem).
    # O File.basename impede que um nome como "../x.lua" saia da pasta dos scripts.
    def read(name)
      key = File.basename(name)
      @mutex.synchronize do
        return @contents[key] if @contents.key?(key)

        @contents[key] = load(key)
      end
    end

    private

    def load(key)
      path = FOLDERS.map { |folder| File.join(@root, folder, key) }.find { |candidate| File.file?(candidate) }
      path && File.binread(path)
    end
  end
end
