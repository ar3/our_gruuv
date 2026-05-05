# frozen_string_literal: true

class BackfillCompletedMaapAgentRunVersions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  class MigrationMaapAgentRun < ApplicationRecord
    self.table_name = 'maap_agent_runs'
  end

  class MigrationVersion < ApplicationRecord
    self.table_name = 'versions'
  end

  def up
    MigrationMaapAgentRun.where(status: 'completed').find_each do |run|
      next if completion_version_exists?(run.id)

      MigrationVersion.create!(
        item_type: 'MaapAgentRun',
        item_id: run.id,
        event: 'update',
        whodunnit: run.triggered_by_teammate_id&.to_s,
        created_at: run.updated_at,
        object: nil,
        object_changes: nil,
        meta: {
          completed_event: true,
          completed_triggered_by_teammate_id: run.triggered_by_teammate_id,
          agent_kind: run.agent_kind,
          backfilled: true
        }
      )
    end
  end

  def down
    MigrationVersion
      .where(item_type: 'MaapAgentRun')
      .where("meta @> ?", { completed_event: true, backfilled: true }.to_json)
      .delete_all
  end

  private

  def completion_version_exists?(run_id)
    MigrationVersion
      .where(item_type: 'MaapAgentRun', item_id: run_id)
      .where("meta @> ?", { completed_event: true }.to_json)
      .exists?
  end
end
