# frozen_string_literal: true

class CreateAssignmentFlowMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :assignment_flow_memberships do |t|
      t.references :assignment_flow, null: false, foreign_key: true
      t.references :assignment, null: false, foreign_key: true
      t.integer :placement, null: false
      t.references :added_by, null: false, foreign_key: { to_table: :teammates }

      t.timestamps
    end

    add_index :assignment_flow_memberships, [:assignment_flow_id, :assignment_id], unique: true, name: 'idx_afm_flow_assignment_unique'
    add_index :assignment_flow_memberships, [:assignment_flow_id, :placement], name: 'idx_afm_flow_placement'
  end
end
