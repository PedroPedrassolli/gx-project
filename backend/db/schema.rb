# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_08_120100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "banlist_entries", force: :cascade do |t|
    t.bigint "banlist_id", null: false
    t.bigint "card_id", null: false
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["banlist_id", "card_id"], name: "index_banlist_entries_on_banlist_id_and_card_id", unique: true
    t.index ["card_id"], name: "index_banlist_entries_on_card_id"
  end

  create_table "banlists", force: :cascade do |t|
    t.string "name", null: false
    t.integer "source_revision"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_banlists_on_name", unique: true
  end

  create_table "cards", force: :cascade do |t|
    t.integer "engine_code", null: false
    t.integer "passcode"
    t.integer "internal_number"
    t.string "name", null: false
    t.string "name_in_game"
    t.integer "source_revision", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name_pt"
    t.string "card_type"
    t.string "property"
    t.string "card_attribute"
    t.string "race"
    t.string "monster_types", default: [], null: false, array: true
    t.integer "level"
    t.integer "attack"
    t.integer "defense"
    t.text "text"
    t.text "text_pt"
    t.integer "image_code"
    t.index ["engine_code"], name: "index_cards_on_engine_code", unique: true
  end

  create_table "collection_cards", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "card_id", null: false
    t.integer "quantity", null: false
    t.datetime "obtained_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_collection_cards_on_card_id"
    t.index ["user_id", "card_id"], name: "index_collection_cards_on_user_id_and_card_id", unique: true
  end

  create_table "converter_group_cards", force: :cascade do |t|
    t.bigint "converter_group_id", null: false
    t.bigint "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_converter_group_cards_on_card_id"
    t.index ["converter_group_id", "card_id"], name: "index_converter_group_cards_on_converter_group_id_and_card_id", unique: true
  end

  create_table "converter_groups", force: :cascade do |t|
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["amount"], name: "index_converter_groups_on_amount", unique: true
  end

  create_table "deck_cards", force: :cascade do |t|
    t.bigint "deck_id", null: false
    t.bigint "card_id", null: false
    t.string "section", null: false
    t.integer "quantity", null: false
    t.boolean "destiny", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_deck_cards_on_card_id"
    t.index ["deck_id", "card_id", "section"], name: "index_deck_cards_on_deck_id_and_card_id_and_section", unique: true
  end

  create_table "decks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_decks_on_user_id"
  end

  create_table "pack_cards", force: :cascade do |t|
    t.bigint "pack_id", null: false
    t.bigint "card_id", null: false
    t.string "rarity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_pack_cards_on_card_id"
    t.index ["pack_id", "card_id"], name: "index_pack_cards_on_pack_id_and_card_id", unique: true
  end

  create_table "packs", force: :cascade do |t|
    t.string "name", null: false
    t.integer "position", null: false
    t.integer "price", null: false
    t.integer "cards_per_pack", null: false
    t.jsonb "availability", default: {}, null: false
    t.integer "source_revision", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_packs_on_name", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "nickname", null: false
    t.string "age_group", null: false
    t.string "role", default: "player", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((nickname)::text)", name: "index_users_on_lower_nickname", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "banlist_entries", "banlists"
  add_foreign_key "banlist_entries", "cards"
  add_foreign_key "collection_cards", "cards"
  add_foreign_key "collection_cards", "users"
  add_foreign_key "converter_group_cards", "cards"
  add_foreign_key "converter_group_cards", "converter_groups"
  add_foreign_key "deck_cards", "cards"
  add_foreign_key "deck_cards", "decks"
  add_foreign_key "decks", "users"
  add_foreign_key "pack_cards", "cards"
  add_foreign_key "pack_cards", "packs"
  add_foreign_key "sessions", "users"
end
