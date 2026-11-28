require "set"
require "sqlite3"

module GameData
  # As cartas que entram no duelo sem estar no pool (GXP-141): as fichas que as cartas do pool
  # criam e as cartas citadas pelo número nos scripts delas (a carta que um efeito cria, o nome
  # que ele dá). O workflow das imagens publica as imagens delas junto com as do pool; o resumo
  # que a mesa mostra vem do banco da engine (Duel::CardSummary). Não depende do Rails.
  module Auxiliary
    FOLDERS = %w[official pre-errata unofficial].freeze # as pastas que o Duel::ScriptLibrary lê
    TOKEN = 0x4000
    NUMBER = /\b\d{6,9}\b/
    CONSTANT = /^\s*((?:TOKEN|CARD)_\w+)\s*=\s*(\d+)/

    module_function

    # scripts: a pasta do CardScripts; database: o cards.cdb, que só tem as cartas oficiais (as
    # do anime não têm imagem no YGOPRODeck); pool: os códigos da engine das cartas do pool.
    # Devolve, em ordem, os códigos de fora do pool que existem no cards.cdb.
    def codes(scripts:, database:, pool:)
      db = SQLite3::Database.new(database, readonly: true)
      type = ->(code) { db.get_first_value("SELECT type FROM datas WHERE id = ?", code) }
      paths = paths(scripts)
      constants = constants(scripts)
      found = pool.flat_map { |code| cited(code, paths[code], constants) + tokens_after(code, type) }
      (found.to_set - pool).select { |code| type.call(code) }.sort
    ensure
      db&.close
    end

    # O script de cada código: o primeiro achado, na ordem em que a engine procura.
    def paths(scripts)
      FOLDERS.flat_map { |folder| Dir[File.join(scripts, folder, "c*.lua")] }
             .each_with_object({}) { |path, paths| paths[File.basename(path)[/\d+/].to_i] ||= path }
    end

    # TOKEN_ROSE = 31986289, CARD_HARPIE_LADY = 76812113... (constant.lua e afins).
    def constants(scripts)
      Dir[File.join(scripts, "*.lua")].each_with_object({}) do |path, constants|
        File.binread(path).scan(CONSTANT) { |name, value| constants[name] = value.to_i }
      end
    end

    # Os códigos que o script cita: o número escrito, "id+1" e as constantes.
    def cited(code, path, constants)
      return [] unless path

      source = File.binread(path)
      source.scan(NUMBER).map(&:to_i) + source.scan(/\bid\s*\+\s*(\d+)/).map { |(step)| code + step.to_i } +
        source.scan(/\b(?:TOKEN|CARD)_\w+/).filter_map { |name| constants[name] }
    end

    # As fichas logo depois do código da carta, uma por arte: o Scapegoat (73915051) cria as
    # quatro "Sheep Token" de 73915052 a 73915055 com "id+i" num laço.
    def tokens_after(code, type)
      (1..).lazy.map { |step| code + step }.take_while { |next_code| type.call(next_code).to_i.anybits?(TOKEN) }.to_a
    end
  end
end
