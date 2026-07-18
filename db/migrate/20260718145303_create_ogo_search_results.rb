# frozen_string_literal: true

class CreateOgoSearchResults < ActiveRecord::Migration[8.0]
  def change
    create_table :ogo_search_results do |t|
      t.references :og_consultation, null: false, foreign_key: true, index: { unique: true }
      t.integer :items_count, null: false, default: 0
      t.integer :extraction_version
      t.timestamps
    end
  end
end
