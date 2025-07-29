class AddTypeToAssignmentOutcomes < ActiveRecord::Migration[8.0]
  def change
    add_column :assignment_outcomes, :type, :string
  end
end
