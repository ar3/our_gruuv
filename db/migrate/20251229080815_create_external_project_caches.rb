class CreateExternalProjectCaches < ActiveRecord::Migration[8.0]
  def change
    create_table :external_project_caches do |t|
      t.references :cacheable, polymorphic: true, null: false, index: true
      t.string :source, null: false, index: true
      t.string :external_project_id, null: false, index: true
      t.string :external_project_url
      t.jsonb :sections_data, default: {}
      t.jsonb :items_data, default: {}
      t.boolean :has_more_items, default: false
      t.datetime :last_synced_at
      t.references :last_synced_by_teammate, foreign_key: { to_table: :teammates }, index: true, null: true

      t.timestamps
    end

    add_index :external_project_caches, [:cacheable_type, :cacheable_id, :source], unique: true, name: "index_external_project_caches_on_cacheable_and_source"
    add_index :external_project_caches, [:source, :last_synced_at], name: "index_external_project_caches_on_source_and_synced_at"
  end
end

