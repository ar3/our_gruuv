# frozen_string_literal: true

class DropHighlightsEnabledFromOrganizations < ActiveRecord::Migration[7.2]
  def change
    remove_index :organizations, name: "index_organizations_on_highlights_enabled", if_exists: true
    remove_column :organizations, :highlights_enabled, :boolean, default: false, null: false
  end
end
