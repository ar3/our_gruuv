# frozen_string_literal: true

class AddDecisionToPositionSuggestionMilestones < ActiveRecord::Migration[8.0]
  def change
    change_table :position_suggestion_milestones, bulk: true do |t|
      t.string :decision
      t.references :processed_by, foreign_key: { to_table: :teammates }
      t.datetime :processed_at
    end
  end
end
