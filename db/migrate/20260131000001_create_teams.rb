class CreateTeams < ActiveRecord::Migration[8.0]
  def change
    create_table :teams do |t|
      t.references :company, null: false, foreign_key: { to_table: :organizations }
      t.string :name, null: false
      t.bigint :migrate_from_organization_id
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :teams, :deleted_at
    add_index :teams, :migrate_from_organization_id, unique: true
  end
end
