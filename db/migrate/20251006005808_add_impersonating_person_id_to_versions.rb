class AddImpersonatingPersonIdToVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :versions, :impersonating_person_id, :bigint
  end
end
