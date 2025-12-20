class AddAssociationsToSeats < ActiveRecord::Migration[8.0]
  def change
    add_column :seats, :department_id, :bigint, null: true
    add_column :seats, :team_id, :bigint, null: true
    add_column :seats, :reports_to_seat_id, :bigint, null: true
    
    add_foreign_key :seats, :organizations, column: :department_id
    add_foreign_key :seats, :organizations, column: :team_id
    add_foreign_key :seats, :seats, column: :reports_to_seat_id
    
    add_index :seats, :department_id
    add_index :seats, :team_id
    add_index :seats, :reports_to_seat_id
  end
end
