# frozen_string_literal: true

class AddSyncStatusToExternalProjectCaches < ActiveRecord::Migration[8.0]
  def change
    change_table :external_project_caches, bulk: true do |t|
      t.string :sync_status
      t.string :sync_error_type
      t.text :sync_error
      t.datetime :sync_started_at
    end

    add_index :external_project_caches, :sync_status
  end
end
