# frozen_string_literal: true

class RenameKudosCelebratoryToKudosPointsEconomyConfig < ActiveRecord::Migration[7.0]
  def up
    return if column_exists?(:organizations, :kudos_points_economy_config)

    rename_column :organizations, :kudos_celebratory_config, :kudos_points_economy_config
    if index_exists?(:organizations, :kudos_points_economy_config, name: "index_organizations_on_kudos_celebratory_config")
      rename_index :organizations, :index_organizations_on_kudos_celebratory_config, :index_organizations_on_kudos_points_economy_config
    end
  end

  def down
    return unless column_exists?(:organizations, :kudos_points_economy_config)

    if index_exists?(:organizations, :kudos_points_economy_config, name: "index_organizations_on_kudos_points_economy_config")
      rename_index :organizations, :index_organizations_on_kudos_points_economy_config, :index_organizations_on_kudos_celebratory_config
    end
    rename_column :organizations, :kudos_points_economy_config, :kudos_celebratory_config
  end
end
