# frozen_string_literal: true

class RenameTriggeredByOnMaapAgentRunsToTriggeredByTeammate < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :maap_agent_runs, column: :triggered_by_id
    rename_column :maap_agent_runs, :triggered_by_id, :triggered_by_teammate_id
    add_foreign_key :maap_agent_runs, :teammates, column: :triggered_by_teammate_id
  end
end
