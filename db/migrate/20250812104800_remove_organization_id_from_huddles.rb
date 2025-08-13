class RemoveOrganizationIdFromHuddles < ActiveRecord::Migration[8.0]
  def change
    remove_column :huddles, :organization_id, :bigint
  end
end
