# frozen_string_literal: true

class AddGoalIdToObservations < ActiveRecord::Migration[8.0]
  def change
    add_reference :observations, :goal, null: true, foreign_key: { on_delete: :nullify }
    add_index :observations, %i[company_id goal_id]
  end
end
