class AddCreatedByToSlackConfigurations < ActiveRecord::Migration[8.0]
  def change
    add_reference :slack_configurations, :created_by, null: true, foreign_key: { to_table: :people }
  end
end
