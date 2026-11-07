# Catálogo do jogo: cartas, pacotes da loja, banlist e grupos do conversor. Os dados vêm
# dos YAML de db/seeds/jogo, pelo `bin/rails catalogo:importar`.
class CreateCatalog < ActiveRecord::Migration[8.1]
  def change
    create_table :cards do |t|
      t.integer :engine_code, null: false # código que a engine usa (cobertura.yml)
      t.integer :passcode # passcode oficial; as cartas do anime não têm
      t.integer :internal_number # número interno do jogo de referência (cartas do anime)
      t.string :name, null: false
      t.string :name_in_game # nome que o jogo usava, quando mudou depois
      t.integer :source_revision, null: false # revisão da página na Yugipedia
      t.timestamps
    end
    add_index :cards, :engine_code, unique: true

    create_table :packs do |t|
      t.string :name, null: false
      t.integer :position, null: false # ordem na loja
      t.integer :price, null: false # em DP
      t.integer :cards_per_pack, null: false
      t.jsonb :availability, null: false, default: {}
      t.integer :source_revision, null: false
      t.timestamps
    end
    add_index :packs, :name, unique: true

    create_table :pack_cards do |t|
      t.references :pack, null: false, foreign_key: true, index: false
      t.references :card, null: false, foreign_key: true
      t.string :rarity, null: false
      t.timestamps
    end
    add_index :pack_cards, [ :pack_id, :card_id ], unique: true

    create_table :banlists do |t|
      t.string :name, null: false
      t.integer :source_revision
      t.timestamps
    end
    add_index :banlists, :name, unique: true

    create_table :banlist_entries do |t|
      t.references :banlist, null: false, foreign_key: true, index: false
      t.references :card, null: false, foreign_key: true
      t.string :status, null: false
      t.timestamps
    end
    add_index :banlist_entries, [ :banlist_id, :card_id ], unique: true

    create_table :converter_groups do |t|
      t.integer :amount, null: false # quantas cartas o jogador põe (10 a 99)
      t.timestamps
    end
    add_index :converter_groups, :amount, unique: true

    create_table :converter_group_cards do |t|
      t.references :converter_group, null: false, foreign_key: true, index: false
      t.references :card, null: false, foreign_key: true
      t.timestamps
    end
    add_index :converter_group_cards, [ :converter_group_id, :card_id ], unique: true
  end
end
