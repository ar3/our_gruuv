class FixSeatsSchema < ActiveRecord::Migration[8.0]
  def up
    # Fix the malformed column name by recreating it
    remove_column :seats, :seat_disclaimer
    add_column :seats, :seat_disclaimer, :text, default: "This job description is not designed to cover or contain a comprehensive list of duties or responsibilities. Duties may change or new ones may be assigned at any time."
    
    # Fix the state column type
    change_column :seats, :state, :string, default: 'draft', null: false
    
    # Fix reports_to and team to be strings instead of text
    change_column :seats, :reports_to, :string
    change_column :seats, :team, :string
  end

  def down
    # Revert changes
    change_column :seats, :state, :integer, default: 0, null: false
    change_column :seats, :reports_to, :text
    change_column :seats, :team, :text
    remove_column :seats, :seat_disclaimer
    add_column :seats, :seat_disclaimer, :text
  end
end
