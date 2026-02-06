# frozen_string_literal: true

class RenameKudosToHighlights < ActiveRecord::Migration[8.0]
  def change
    # Rename tables
    rename_table :kudos_points_ledgers, :highlights_points_ledgers
    rename_table :kudos_transactions, :highlights_transactions

    # Rename columns in teammates table
    rename_column :teammates, :can_manage_kudos_rewards, :can_manage_highlights_rewards

    # Rename columns in organizations table
    rename_column :organizations, :kudos_enabled, :highlights_enabled
    rename_column :organizations, :kudos_celebratory_config, :highlights_celebratory_config

    # Rename column in highlights_transactions (formerly kudos_transactions)
    rename_column :highlights_transactions, :kudos_redemption_id, :highlights_redemption_id
  end
end
