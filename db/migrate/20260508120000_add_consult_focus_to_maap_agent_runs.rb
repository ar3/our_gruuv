# frozen_string_literal: true

class AddConsultFocusToMaapAgentRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :maap_agent_runs, :consult_focus, :text
  end
end
