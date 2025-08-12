class AddOgAdminToPeople < ActiveRecord::Migration[8.0]
  def change
    add_column :people, :og_admin, :boolean, default: false, null: false
    add_index :people, :og_admin
  end
end
