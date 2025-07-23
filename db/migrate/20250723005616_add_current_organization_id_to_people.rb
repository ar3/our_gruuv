class AddCurrentOrganizationIdToPeople < ActiveRecord::Migration[8.0]
  def change
    add_column :people, :current_organization_id, :integer
    add_index :people, :current_organization_id
    add_foreign_key :people, :organizations, column: :current_organization_id
  end
end
