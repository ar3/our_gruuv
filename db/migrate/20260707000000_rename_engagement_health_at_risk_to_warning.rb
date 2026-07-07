# frozen_string_literal: true

class RenameEngagementHealthAtRiskToWarning < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE engagement_health_statuses
      SET status = 'warning'
      WHERE status = 'at_risk'
    SQL

    execute <<~SQL.squish
      UPDATE engagement_health_weekly_rollups
      SET status = 'warning'
      WHERE status = 'at_risk'
    SQL

    execute <<~SQL.squish
      UPDATE engagement_health_statuses
      SET inputs = (inputs - 'days_until_at_risk')
        || jsonb_build_object('days_until_warning', inputs->'days_until_at_risk')
      WHERE inputs ? 'days_until_at_risk'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE engagement_health_statuses
      SET status = 'at_risk'
      WHERE status = 'warning'
    SQL

    execute <<~SQL.squish
      UPDATE engagement_health_weekly_rollups
      SET status = 'at_risk'
      WHERE status = 'warning'
    SQL

    execute <<~SQL.squish
      UPDATE engagement_health_statuses
      SET inputs = (inputs - 'days_until_warning')
        || jsonb_build_object('days_until_at_risk', inputs->'days_until_warning')
      WHERE inputs ? 'days_until_warning'
    SQL
  end
end
