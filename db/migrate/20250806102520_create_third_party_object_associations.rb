class CreateThirdPartyObjectAssociations < ActiveRecord::Migration[8.0]
  def change
    create_table :third_party_object_associations do |t|
      t.references :third_party_object, null: false, foreign_key: true
      t.references :associatable, polymorphic: true, null: false
      t.string :association_type, null: false

      t.timestamps
    end

    add_index :third_party_object_associations, [:associatable_type, :associatable_id, :association_type], unique: true, name: 'index_third_party_associations_on_associatable_and_type'
    add_index :third_party_object_associations, [:third_party_object_id, :association_type], name: 'index_third_party_associations_on_object_and_type'
  end
end
