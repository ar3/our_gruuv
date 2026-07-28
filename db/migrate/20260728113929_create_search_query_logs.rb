# frozen_string_literal: true

class CreateSearchQueryLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :search_query_logs do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :company_teammate, null: false, foreign_key: { to_table: :teammates }
      t.string :query, null: false
      t.integer :results_count, null: false, default: 0

      t.timestamps
    end

    add_index :search_query_logs, [:company_teammate_id, :created_at]
    add_index :search_query_logs, [:organization_id, :created_at]
  end
end
