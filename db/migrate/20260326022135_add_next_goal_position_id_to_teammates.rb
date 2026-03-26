class AddNextGoalPositionIdToTeammates < ActiveRecord::Migration[8.0]
  def change
    add_reference :teammates, :next_goal_position, null: true, foreign_key: { to_table: :positions }, index: true
  end
end
