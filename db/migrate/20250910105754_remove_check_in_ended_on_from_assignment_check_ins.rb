class RemoveCheckInEndedOnFromAssignmentCheckIns < ActiveRecord::Migration[8.0]
  def change
    remove_column :assignment_check_ins, :check_in_ended_on, :date
  end
end
