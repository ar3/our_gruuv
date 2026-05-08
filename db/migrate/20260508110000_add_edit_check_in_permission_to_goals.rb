class AddEditCheckInPermissionToGoals < ActiveRecord::Migration[8.0]
  def change
    add_column :goals, :edit_check_in_permission, :string, default: 'anyone_who_can_view', null: false
    add_index :goals, :edit_check_in_permission
  end
end

