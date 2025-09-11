class AddManagerTrackingToAssignmentCheckIns < ActiveRecord::Migration[8.0]
  def change
    add_column :assignment_check_ins, :employee_completed_by_id, :integer
    add_column :assignment_check_ins, :manager_completed_by_id, :integer
    add_column :assignment_check_ins, :finalized_by_id, :integer

    add_index :assignment_check_ins, :employee_completed_by_id
    add_index :assignment_check_ins, :manager_completed_by_id
    add_index :assignment_check_ins, :finalized_by_id

    add_foreign_key :assignment_check_ins, :people, column: :employee_completed_by_id
    add_foreign_key :assignment_check_ins, :people, column: :manager_completed_by_id
    add_foreign_key :assignment_check_ins, :people, column: :finalized_by_id
  end
end
