# frozen_string_literal: true

class AddClarityScoreToMaapAgentRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :maap_agent_runs, :clarity_score, :integer
  end
end
