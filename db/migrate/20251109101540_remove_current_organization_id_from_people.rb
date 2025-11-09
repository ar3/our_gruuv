class RemoveCurrentOrganizationIdFromPeople < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :people, :organizations, column: :current_organization_id if foreign_key_exists?(:people, :organizations, column: :current_organization_id)
    remove_index :people, :current_organization_id if index_exists?(:people, :current_organization_id)
    remove_column :people, :current_organization_id, :integer
  end
end
