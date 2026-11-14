class AddUniqueIndexToBillingInvoicesDueOn < ActiveRecord::Migration[8.0]
  def change
    remove_index :billing_invoices, [:organization_id, :due_on]
    add_index :billing_invoices, [:organization_id, :due_on], unique: true
  end
end
