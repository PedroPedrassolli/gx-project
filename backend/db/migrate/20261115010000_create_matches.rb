# Partidas (escopo 5.7; ADR 0011): o duelo de uma sala. O estado do duelo é a semente, os
# decks embaralhados e a lista de respostas; a engine refaz o resto (ADR 0001).
class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches do |t|
      # A sala pode sumir (o dono saiu): a partida fica, para o replay.
      t.references :room, foreign_key: { on_delete: :nullify }
      t.string :mode, null: false, default: "1x1"
      t.boolean :banlist, null: false
      t.boolean :destiny_draw, null: false
      # Quatro números de 63 bits: a semente da engine (OCG_DuelOptions.seed).
      t.bigint :seed, array: true, null: false
      t.string :status, null: false, default: "dueling"
      t.integer :winner_team
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps
    end

    # team 0 começa o duelo. O deck guardado já vem embaralhado: a engine não embaralha no
    # começo, e o replay precisa da mesma ordem.
    create_table :match_players do |t|
      t.references :match, null: false, foreign_key: true, index: false
      # Quem apaga a conta some da partida, mas o duelo fica para o outro jogador.
      t.references :user, foreign_key: { on_delete: :nullify }
      t.integer :team, null: false
      t.integer :seat, null: false
      t.jsonb :deck, null: false
      t.timestamps
    end
    add_index :match_players, %i[match_id team], unique: true

    create_table :match_responses do |t|
      t.references :match, null: false, foreign_key: true, index: false
      t.integer :seq, null: false
      t.integer :team, null: false
      t.binary :bytes, null: false
      t.datetime :created_at, null: false
    end
    add_index :match_responses, %i[match_id seq], unique: true
  end
end
