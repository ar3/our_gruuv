class RemoveCurrentPersonIdAndImpersonatingPersonIdFromVersions < ActiveRecord::Migration[8.0]
  def change
    remove_column :versions, :current_person_id, :bigint
    remove_column :versions, :impersonating_person_id, :bigint
  end
end
