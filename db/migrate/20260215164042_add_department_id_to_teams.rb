class AddDepartmentIdToTeams < ActiveRecord::Migration[8.0]
  def change
    add_reference :teams, :department, type: :bigint, null: true, index: true, foreign_key: true
  end
end
