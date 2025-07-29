class RenameTypeToOutcomeTypeInAssignmentOutcomes < ActiveRecord::Migration[8.0]
  def change
    rename_column :assignment_outcomes, :type, :outcome_type
  end
end
