# frozen_string_literal: true

class DropMaapAgentRuns < ActiveRecord::Migration[8.0]
  def up
    drop_table :maap_recommendation_acceptances, if_exists: true
    drop_table :maap_agent_runs, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
