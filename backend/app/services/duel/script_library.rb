module Duel
  # Encontra os scripts Lua das cartas (CardScripts) e guarda o conteúdo em memória
  # depois da primeira leitura, para o replay não ir ao disco de novo.
  class ScriptLibrary
    # A raiz tem constant.lua, utility.lua e os proc_*.lua; depois vêm as cartas.
    FOLDERS = [ "", "official", "pre-errata", "unofficial" ].freeze

    def self.default
      new(Rails.root.join("vendor/engine/CardScripts"))
    end

    def initialize(root)
      @paths = {}
      FOLDERS.each do |folder|
        Dir.glob(File.join(root.to_s, folder, "*.lua")).each do |path|
          @paths[File.basename(path)] ||= path
        end
      end
      @contents = {}
    end

    def size = @paths.size

    # Conteúdo do script, ou nil quando não existe (carta Normal não tem script, e tudo bem).
    def read(name)
      key = File.basename(name)
      return @contents[key] if @contents.key?(key)

      path = @paths[key]
      @contents[key] = path && File.binread(path)
    end
  end
end
