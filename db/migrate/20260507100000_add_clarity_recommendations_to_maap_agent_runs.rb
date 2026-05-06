# frozen_string_literal: true

class AddClarityRecommendationsToMaapAgentRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :maap_agent_runs, :clarity_recommendations, :jsonb, default: [], null: false
  end
end
