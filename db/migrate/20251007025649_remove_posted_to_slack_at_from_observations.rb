class RemovePostedToSlackAtFromObservations < ActiveRecord::Migration[8.0]
  def up
    remove_column :observations, :posted_to_slack_at
  end

  def down
    add_column :observations, :posted_to_slack_at, :datetime
  end
end