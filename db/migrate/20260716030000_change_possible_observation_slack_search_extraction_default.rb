# frozen_string_literal: true

class ChangePossibleObservationSlackSearchExtractionDefault < ActiveRecord::Migration[8.0]
  def up
    change_column_default :possible_observation_slack_searches, :extraction_status, from: "pending", to: "ready"
    execute <<~SQL.squish
      UPDATE possible_observation_slack_searches
      SET extraction_status = 'ready'
      WHERE search_status = 'completed'
        AND extraction_status = 'pending'
        AND (extractions IS NULL OR extractions = '{}'::jsonb OR extractions = '{"version":1,"items":[]}'::jsonb OR NOT (extractions ? 'items') OR jsonb_array_length(COALESCE(extractions->'items', '[]'::jsonb)) = 0)
    SQL
  end

  def down
    change_column_default :possible_observation_slack_searches, :extraction_status, from: "ready", to: "pending"
  end
end
