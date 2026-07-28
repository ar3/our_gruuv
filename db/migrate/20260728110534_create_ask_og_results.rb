# frozen_string_literal: true

class CreateAskOgResults < ActiveRecord::Migration[8.0]
  def change
    create_table :ask_og_results do |t|
      t.references :og_consultation, null: false, foreign_key: true, index: { unique: true }
      t.string :query, null: false
      t.text :answer_text
      t.jsonb :proposed_actions, null: false, default: []
      t.jsonb :tool_context, null: false, default: {}

      t.timestamps
    end
  end
end
