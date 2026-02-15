# frozen_string_literal: true

class CreateTeamAsanaLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :team_asana_links do |t|
      t.references :team, null: false, foreign_key: true, index: { unique: true }
      t.string :url
      t.jsonb :deep_integration_config, default: {}

      t.timestamps
    end
  end
end
