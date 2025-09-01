class CreateAbilities < ActiveRecord::Migration[8.0]
  def change
    create_table :abilities do |t|
      t.string :name, null: false
      t.text :description, null: false
      t.string :version, null: false, default: '1.0.0'
      t.references :organization, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :people }
      t.references :updated_by, null: false, foreign_key: { to_table: :people }

      t.timestamps
    end

    add_index :abilities, [:name, :organization_id], unique: true
  end
end
