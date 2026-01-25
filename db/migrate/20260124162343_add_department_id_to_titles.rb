class AddDepartmentIdToTitles < ActiveRecord::Migration[8.0]
  def change
    add_column :titles, :department_id, :bigint, null: true
    add_foreign_key :titles, :organizations, column: :department_id
    add_index :titles, :department_id
  end
end
