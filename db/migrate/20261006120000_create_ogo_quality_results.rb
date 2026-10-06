# frozen_string_literal: true

class CreateOgoQualityResults < ActiveRecord::Migration[8.0]
  def change
    create_table :ogo_quality_results do |t|
      t.references :og_consultation, null: false, foreign_key: true, index: { unique: true }
      t.text :output_text
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
  end
end
