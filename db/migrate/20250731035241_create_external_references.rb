class CreateExternalReferences < ActiveRecord::Migration[8.0]
  def change
    create_table :external_references do |t|
      t.references :referable, polymorphic: true, null: false
      t.string :url
      t.jsonb :source_data
      t.datetime :last_synced_at
      t.string :reference_type

      t.timestamps
    end
    
    add_index :external_references, [:referable_type, :referable_id, :reference_type], 
              name: 'index_external_references_on_referable_and_type'
  end
end
