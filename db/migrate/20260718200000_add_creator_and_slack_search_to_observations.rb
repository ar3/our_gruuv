# frozen_string_literal: true

class AddCreatorAndSlackSearchToObservations < ActiveRecord::Migration[8.0]
  def up
    add_reference :observations, :creator_company_teammate,
                  null: true,
                  foreign_key: { to_table: :teammates },
                  index: true
    add_reference :observations, :possible_observation_slack_search,
                  null: true,
                  foreign_key: true,
                  index: true

    # Backfill creator to the observer's teammate in the observation's company.
    execute <<~SQL.squish
      UPDATE observations
      SET creator_company_teammate_id = teammates.id
      FROM teammates
      WHERE teammates.person_id = observations.observer_id
        AND teammates.organization_id = observations.company_id
        AND observations.creator_company_teammate_id IS NULL
    SQL
  end

  def down
    remove_reference :observations, :possible_observation_slack_search, foreign_key: true
    remove_reference :observations, :creator_company_teammate, foreign_key: { to_table: :teammates }
  end
end
