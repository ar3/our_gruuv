class RemoveParentIdFromOrganizations < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :organizations, :organizations, column: :parent_id, if_exists: true
    remove_index :organizations, :parent_id, if_exists: true
    remove_column :organizations, :parent_id, :bigint
  end
end
