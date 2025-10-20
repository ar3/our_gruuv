class CreateEnmAssessments < ActiveRecord::Migration[8.0]
  def change
    create_table :enm_assessments do |t|
      t.string :code, null: false, limit: 8
      t.jsonb :phase_1_data, default: {}
      t.jsonb :phase_2_data, default: {}
      t.jsonb :phase_3_data, default: {}
      t.string :macro_category, limit: 1
      t.string :readiness, limit: 1
      t.string :style, limit: 1
      t.string :full_code, limit: 5
      t.integer :completed_phase, default: 0

      t.timestamps
    end
    
    add_index :enm_assessments, :code, unique: true
    add_index :enm_assessments, :macro_category
    add_index :enm_assessments, :full_code
    add_index :enm_assessments, :completed_phase
  end
end
