class CreateKudosTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :kudos_transactions do |t|
      t.string :type, null: false # STI discriminator
      t.bigint :company_teammate_id, null: false
      t.bigint :organization_id, null: false
      t.decimal :points_to_give_delta, precision: 10, scale: 1, default: 0
      t.decimal :points_to_spend_delta, precision: 10, scale: 1, default: 0

      # Type-specific columns (nullable at DB level, validated in subclasses)
      t.bigint :observation_id # For PointsExchangeTransaction and KickbackRewardTransaction
      t.bigint :triggering_transaction_id # For KickbackRewardTransaction
      t.bigint :company_teammate_banker_id # For BankAwardTransaction
      t.text :reason # For BankAwardTransaction
      t.bigint :kudos_redemption_id # For RedemptionTransaction

      t.timestamps
    end

    add_index :kudos_transactions, :type
    add_index :kudos_transactions, :company_teammate_id
    add_index :kudos_transactions, :organization_id
    add_index :kudos_transactions, :observation_id
    add_index :kudos_transactions, :kudos_redemption_id
    add_index :kudos_transactions, :company_teammate_banker_id
    add_index :kudos_transactions, :triggering_transaction_id
    add_index :kudos_transactions, [:company_teammate_id, :created_at], name: 'index_kudos_transactions_on_teammate_and_date'

    add_foreign_key :kudos_transactions, :teammates, column: :company_teammate_id
    add_foreign_key :kudos_transactions, :organizations, column: :organization_id
    add_foreign_key :kudos_transactions, :observations, column: :observation_id
    add_foreign_key :kudos_transactions, :kudos_transactions, column: :triggering_transaction_id
    add_foreign_key :kudos_transactions, :teammates, column: :company_teammate_banker_id
    # Note: kudos_redemption_id foreign key will be added when kudos_redemptions table is created in Phase 5
  end
end
