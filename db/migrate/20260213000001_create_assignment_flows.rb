# frozen_string_literal: true

class CreateAssignmentFlows < ActiveRecord::Migration[8.0]
  def change
    create_table :assignment_flows do |t|
      t.string :name, null: false
      t.references :company, null: false, foreign_key: { to_table: :organizations }
      t.references :created_by, null: false, foreign_key: { to_table: :teammates }
      t.references :updated_by, null: false, foreign_key: { to_table: :teammates }

      t.timestamps
    end

    add_index :assignment_flows, [:company_id, :name], unique: true
  end
end
