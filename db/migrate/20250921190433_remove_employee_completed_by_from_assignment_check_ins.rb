class RemoveEmployeeCompletedByFromAssignmentCheckIns < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :assignment_check_ins, :people, column: :employee_completed_by_id
    remove_index :assignment_check_ins, :employee_completed_by_id
    remove_column :assignment_check_ins, :employee_completed_by_id, :integer
  end
end
