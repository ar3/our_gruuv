class AddKudosConfigToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :kudos_enabled, :boolean, default: false, null: false
    add_column :organizations, :kudos_celebratory_config, :jsonb, default: {}

    add_index :organizations, :kudos_enabled
    add_index :organizations, :kudos_celebratory_config, using: :gin
  end
end
