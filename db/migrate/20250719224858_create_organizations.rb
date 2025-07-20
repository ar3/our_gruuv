class CreateOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :organizations do |t|
      t.string :name
      t.string :type
      t.references :parent, null: true, foreign_key: { to_table: :organizations }

      t.timestamps
    end
  end
end
