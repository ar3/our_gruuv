class CreateEnmPartnerships < ActiveRecord::Migration[8.0]
  def change
    create_table :enm_partnerships do |t|
      t.string :code, null: false, limit: 8
      t.jsonb :assessment_codes, default: []
      t.jsonb :compatibility_analysis, default: {}
      t.string :relationship_type, limit: 1

      t.timestamps
    end
    
    add_index :enm_partnerships, :code, unique: true
    add_index :enm_partnerships, :relationship_type
    add_index :enm_partnerships, :assessment_codes, using: :gin
  end
end
