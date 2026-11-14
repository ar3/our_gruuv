class CreateOrganizationBillingSettingsAndInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :organization_billing_settings do |t|
      t.references :organization, null: false, foreign_key: true, index: { unique: true }
      t.string :cadence, null: false, default: "monthly"
      t.decimal :locked_pepm, precision: 10, scale: 2
      t.date :current_period_starts_on
      t.date :next_payment_due_on
      t.timestamps
    end

    create_table :billing_invoices do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :status, null: false, default: "open"
      t.string :cadence, null: false
      t.date :period_starts_on, null: false
      t.date :period_ends_on, null: false
      t.date :due_on, null: false
      t.decimal :pepm, precision: 10, scale: 2, null: false
      t.integer :teammate_count, null: false, default: 0
      t.decimal :amount_due, precision: 12, scale: 2, null: false
      t.decimal :value_delivered_total, precision: 12, scale: 2
      t.decimal :value_based_pepm, precision: 10, scale: 2
      t.datetime :paid_at
      t.timestamps
    end

    add_index :billing_invoices, [:organization_id, :status]
    add_index :billing_invoices, [:organization_id, :due_on]
  end
end
