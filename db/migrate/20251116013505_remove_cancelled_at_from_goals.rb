class RemoveCancelledAtFromGoals < ActiveRecord::Migration[8.0]
  def change
    remove_column :goals, :cancelled_at, :datetime
  end
end
