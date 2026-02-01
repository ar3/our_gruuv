class CreateDepartments < ActiveRecord::Migration[8.0]
  def change
    create_table :departments do |t|
      t.references :company, null: false, foreign_key: { to_table: :organizations }
      t.references :parent_department, foreign_key: { to_table: :departments }
      t.string :name, null: false
      t.bigint :migrate_from_organization_id
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :departments, :deleted_at
    add_index :departments, :migrate_from_organization_id, unique: true
  end
end
