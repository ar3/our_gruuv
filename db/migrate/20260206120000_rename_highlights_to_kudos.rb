# frozen_string_literal: true

class RenameHighlightsToKudos < ActiveRecord::Migration[8.0]
  def change
    # Rename tables (order: ledgers, rewards, redemptions, then transactions which references redemptions)
    rename_table :highlights_points_ledgers, :kudos_points_ledgers
    rename_table :highlights_rewards, :kudos_rewards
    rename_table :highlights_redemptions, :kudos_redemptions
    rename_table :highlights_transactions, :kudos_transactions

    # Rename FK columns in kudos_redemptions and kudos_transactions
    rename_column :kudos_redemptions, :highlights_reward_id, :kudos_reward_id
    rename_column :kudos_transactions, :highlights_redemption_id, :kudos_redemption_id

    # Rename columns in teammates and organizations
    rename_column :teammates, :can_manage_highlights_rewards, :can_manage_kudos_rewards
    rename_column :organizations, :highlights_celebratory_config, :kudos_celebratory_config
  end
end
