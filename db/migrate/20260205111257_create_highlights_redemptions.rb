# Creates the redemption records for tracking reward fulfillment
class CreateHighlightsRedemptions < ActiveRecord::Migration[8.0]
  def change
    create_table :highlights_redemptions do |t|
      t.references :company_teammate, null: false, foreign_key: { to_table: :teammates }
      t.references :organization, null: false, foreign_key: true
      t.references :highlights_reward, null: false, foreign_key: true
      t.decimal :points_spent, precision: 10, scale: 1, null: false
      t.string :status, null: false, default: 'pending'
      t.datetime :fulfilled_at
      t.string :external_reference
      t.text :notes

      t.timestamps
    end

    add_index :highlights_redemptions, [:company_teammate_id, :status]
    add_index :highlights_redemptions, [:organization_id, :status]
    add_index :highlights_redemptions, :status
    add_index :highlights_redemptions, :external_reference

    # Add foreign key from highlights_transactions to highlights_redemptions
    add_foreign_key :highlights_transactions, :highlights_redemptions, column: :highlights_redemption_id
  end
end
