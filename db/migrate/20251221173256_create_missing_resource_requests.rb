class CreateMissingResourceRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :missing_resource_requests do |t|
      t.references :missing_resource, null: false, foreign_key: true
      t.references :person, null: true, foreign_key: true
      t.string :ip_address, null: false
      t.integer :request_count, default: 1, null: false
      t.text :user_agent
      t.text :referrer
      t.string :request_method
      t.text :query_string
      t.datetime :first_seen_at
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :missing_resource_requests, :ip_address
    add_index :missing_resource_requests, [:missing_resource_id, :person_id, :ip_address], 
              unique: true, name: 'index_missing_resource_requests_unique'
    add_index :missing_resource_requests, :last_seen_at
  end
end
