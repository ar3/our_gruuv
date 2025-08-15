class RenameCheckInDateAndAddEndedOn < ActiveRecord::Migration[8.0]
  def change
    # Rename check_in_date to check_in_started_on (following Rails date naming convention)
    rename_column :assignment_check_ins, :check_in_date, :check_in_started_on
    
    # Add check_in_ended_on for closed check-ins
    add_column :assignment_check_ins, :check_in_ended_on, :date
    
    # Add index for efficient queries on ended check-ins
    add_index :assignment_check_ins, :check_in_ended_on
  end
end
