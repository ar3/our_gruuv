class RemoveDepartmentIdFromSeats < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :seats, :organizations, column: :department_id
    remove_index :seats, :department_id
    remove_column :seats, :department_id, :bigint
  end
end
