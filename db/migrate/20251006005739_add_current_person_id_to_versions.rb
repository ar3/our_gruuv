class AddCurrentPersonIdToVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :versions, :current_person_id, :bigint
  end
end
