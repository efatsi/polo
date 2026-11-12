class CreateGames < ActiveRecord::Migration[7.2]
  def change
    # One row per groups.io topic (email thread). Threads that turn out not to be
    # about a game are kept with status "not_a_game" so they aren't re-processed.
    create_table :games do |t|
      t.bigint :groupsio_topic_id, null: false
      t.string :subject, null: false
      t.string :started_by
      t.datetime :thread_started_at
      t.datetime :last_post_at

      # Effective values shown on the site (from Claude, unless an admin locked them).
      t.datetime :starts_at
      t.boolean :time_tbd, null: false, default: false # date known, start time not settled
      t.string :location
      t.string :status, null: false, default: "proposed"
      t.text :summary

      t.string :locked_fields, array: true, null: false, default: []
      t.jsonb :ai_data, null: false, default: {}
      t.datetime :extracted_at
      t.integer :extracted_through_msg_num

      t.timestamps
    end
    add_index :games, :groupsio_topic_id, unique: true
    add_index :games, :starts_at

    create_table :messages do |t|
      t.references :game, null: false, foreign_key: true
      t.integer :msg_num, null: false
      t.bigint :groupsio_user_id
      t.string :author_name
      t.datetime :sent_at, null: false
      t.text :body, null: false, default: ""
      t.timestamps
    end
    add_index :messages, :msg_num, unique: true

    create_table :attendances do |t|
      t.references :game, null: false, foreign_key: true
      t.string :name, null: false
      t.string :status, null: false # in / maybe / out
      t.string :note
      t.timestamps
    end
    add_index :attendances, [:game_id, :name], unique: true
  end
end
