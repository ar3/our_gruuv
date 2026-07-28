# frozen_string_literal: true

class CreateAskOgMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :ask_og_messages do |t|
      t.references :ask_og_result, null: false, foreign_key: true
      t.string :role, null: false
      t.text :body, null: false
      t.integer :position, null: false
      t.jsonb :proposed_actions, null: false, default: []

      t.timestamps
    end

    add_index :ask_og_messages, [:ask_og_result_id, :position], unique: true
  end
end
