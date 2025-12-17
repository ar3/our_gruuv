class AddCanManageDepartmentsAndTeamsToTeammates < ActiveRecord::Migration[8.0]
  def change
    add_column :teammates, :can_manage_departments_and_teams, :boolean
    add_index :teammates, :can_manage_departments_and_teams
  end
end
