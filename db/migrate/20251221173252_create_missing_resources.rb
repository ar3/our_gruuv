class CreateMissingResources < ActiveRecord::Migration[8.0]
  def change
    create_table :missing_resources do |t|
      t.string :path, null: false
      t.integer :request_count, default: 0, null: false
      t.datetime :first_seen_at
      t.datetime :last_seen_at
      t.string :suggested_redirect_path
      t.integer :suggestion_confidence

      t.timestamps
    end

    add_index :missing_resources, :path, unique: true
    add_index :missing_resources, :request_count
    add_index :missing_resources, :last_seen_at
  end
end
