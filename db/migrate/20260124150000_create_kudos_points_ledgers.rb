class CreateKudosPointsLedgers < ActiveRecord::Migration[8.0]
  def change
    create_table :kudos_points_ledgers do |t|
      t.bigint :company_teammate_id, null: false
      t.bigint :organization_id, null: false
      t.decimal :points_to_give, precision: 10, scale: 1, default: 0, null: false
      t.decimal :points_to_spend, precision: 10, scale: 1, default: 0, null: false

      t.timestamps
    end

    add_index :kudos_points_ledgers, [:company_teammate_id, :organization_id], unique: true, name: 'index_kudos_ledgers_on_teammate_and_organization'
    add_index :kudos_points_ledgers, :organization_id
    add_foreign_key :kudos_points_ledgers, :teammates, column: :company_teammate_id
    add_foreign_key :kudos_points_ledgers, :organizations, column: :organization_id
  end
end
