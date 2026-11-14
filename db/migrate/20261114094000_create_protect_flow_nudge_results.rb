# frozen_string_literal: true

class CreateProtectFlowNudgeResults < ActiveRecord::Migration[7.1]
  def change
    create_table :protect_flow_nudge_results do |t|
      t.bigint :og_consultation_id, null: false
      t.text :output_text
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end

    add_index :protect_flow_nudge_results, :og_consultation_id, unique: true
    add_foreign_key :protect_flow_nudge_results, :og_consultations
  end
end
