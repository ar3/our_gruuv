class AddDepartmentIdToAssignments < ActiveRecord::Migration[8.0]
  def change
    add_reference :assignments, :department, null: true, foreign_key: { to_table: :organizations }
  end
end
