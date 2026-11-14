class AddCanManageBillingToTeammates < ActiveRecord::Migration[8.0]
  def change
    add_column :teammates, :can_manage_billing, :boolean, default: false, null: false
    add_index :teammates, :can_manage_billing
  end
end
