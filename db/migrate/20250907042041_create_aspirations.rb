class CreateAspirations < ActiveRecord::Migration[8.0]
  def change
    create_table :aspirations do |t|
      t.string :name, null: false
      t.text :description
      t.references :organization, null: false, foreign_key: true
      t.integer :sort_order, default: 999, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :aspirations, [:organization_id, :name], unique: true
    add_index :aspirations, :deleted_at
    add_index :aspirations, :sort_order
  end
end
