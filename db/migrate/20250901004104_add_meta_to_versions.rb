class AddMetaToVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :versions, :meta, :jsonb
  end
end
