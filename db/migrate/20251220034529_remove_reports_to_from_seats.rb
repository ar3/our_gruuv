class RemoveReportsToFromSeats < ActiveRecord::Migration[8.0]
  def change
    remove_column :seats, :reports_to, :string
  end
end
