class CreatePositionTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :position_types do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :position_major_level, null: false, foreign_key: true
      t.string :external_title, null: false
      t.text :alternative_titles
      t.text :position_summary

      t.timestamps
    end
    
    add_index :position_types, [:organization_id, :position_major_level_id, :external_title], 
              unique: true, name: 'index_position_types_on_org_level_title_unique'
  end
end
