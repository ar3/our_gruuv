class MakeGoalTargetDatesOptional < ActiveRecord::Migration[8.0]
  def change
    change_column_null :goals, :earliest_target_date, true
    change_column_null :goals, :latest_target_date, true
    change_column_null :goals, :most_likely_target_date, true
  end
end
