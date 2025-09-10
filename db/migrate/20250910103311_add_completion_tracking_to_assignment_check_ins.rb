class AddCompletionTrackingToAssignmentCheckIns < ActiveRecord::Migration[8.0]
  def change
    add_column :assignment_check_ins, :employee_completed_at, :datetime
    add_column :assignment_check_ins, :manager_completed_at, :datetime
    add_column :assignment_check_ins, :official_check_in_completed_at, :datetime

    add_index :assignment_check_ins, :employee_completed_at
    add_index :assignment_check_ins, :manager_completed_at
    add_index :assignment_check_ins, :official_check_in_completed_at
  end
end
