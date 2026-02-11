# frozen_string_literal: true

class ConvertKudosPointsToIntegers < ActiveRecord::Migration[8.0]
  def up
    # kudos_points_ledgers: round existing decimals to integer, then change column type
    execute <<-SQL.squish
      UPDATE kudos_points_ledgers
      SET points_to_give = ROUND(points_to_give::numeric, 0),
          points_to_spend = ROUND(points_to_spend::numeric, 0)
    SQL
    change_column :kudos_points_ledgers, :points_to_give, :integer, default: 0, null: false
    change_column :kudos_points_ledgers, :points_to_spend, :integer, default: 0, null: false

    # kudos_transactions
    execute <<-SQL.squish
      UPDATE kudos_transactions
      SET points_to_give_delta = ROUND(points_to_give_delta::numeric, 0),
          points_to_spend_delta = ROUND(points_to_spend_delta::numeric, 0)
    SQL
    change_column :kudos_transactions, :points_to_give_delta, :integer, default: 0
    change_column :kudos_transactions, :points_to_spend_delta, :integer, default: 0

    # kudos_redemptions
    execute <<-SQL.squish
      UPDATE kudos_redemptions
      SET points_spent = ROUND(points_spent::numeric, 0)
    SQL
    change_column :kudos_redemptions, :points_spent, :integer, null: false

    # kudos_rewards
    execute <<-SQL.squish
      UPDATE kudos_rewards
      SET cost_in_points = ROUND(cost_in_points::numeric, 0)
    SQL
    change_column :kudos_rewards, :cost_in_points, :integer, null: false
  end

  def down
    change_column :kudos_points_ledgers, :points_to_give, :decimal, precision: 10, scale: 1, default: "0.0", null: false
    change_column :kudos_points_ledgers, :points_to_spend, :decimal, precision: 10, scale: 1, default: "0.0", null: false

    change_column :kudos_transactions, :points_to_give_delta, :decimal, precision: 10, scale: 1, default: "0.0"
    change_column :kudos_transactions, :points_to_spend_delta, :decimal, precision: 10, scale: 1, default: "0.0"

    change_column :kudos_redemptions, :points_spent, :decimal, precision: 10, scale: 1, null: false

    change_column :kudos_rewards, :cost_in_points, :decimal, precision: 10, scale: 1, null: false
  end
end
