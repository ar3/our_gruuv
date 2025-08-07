class CreateThirdPartyObjects < ActiveRecord::Migration[8.0]
  def change
    create_table :third_party_objects do |t|
      t.string :display_name, null: false
      t.string :third_party_name, null: false
      t.string :third_party_id, null: false
      t.string :third_party_object_type, null: false
      t.string :third_party_source, null: false
      t.references :organization, null: false, foreign_key: true
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :third_party_objects, [:organization_id, :third_party_id, :third_party_source], unique: true, name: 'index_third_party_objects_on_org_third_party_id_source'
    add_index :third_party_objects, [:organization_id, :third_party_source, :deleted_at], name: 'index_third_party_objects_on_org_source_deleted'
  end
end
