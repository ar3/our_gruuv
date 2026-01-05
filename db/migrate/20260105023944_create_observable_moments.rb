class CreateObservableMoments < ActiveRecord::Migration[8.0]
  def change
    create_table :observable_moments do |t|
      t.string :momentable_type, null: false
      t.bigint :momentable_id, null: false
      t.string :moment_type, null: false
      t.bigint :company_id, null: false
      t.bigint :created_by_id, null: false
      t.bigint :primary_potential_observer_id, null: false
      t.bigint :processed_by_teammate_id
      t.datetime :occurred_at, null: false
      t.datetime :processed_at
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :observable_moments, [:momentable_type, :momentable_id]
    add_index :observable_moments, :company_id
    add_index :observable_moments, :created_by_id
    add_index :observable_moments, :primary_potential_observer_id
    add_index :observable_moments, :moment_type
    add_index :observable_moments, :occurred_at
    add_index :observable_moments, :processed_at
    add_index :observable_moments, :metadata, using: :gin
    add_index :observable_moments, [:primary_potential_observer_id, :processed_at], name: 'index_observable_moments_on_observer_and_processed'
    
    add_foreign_key :observable_moments, :organizations, column: :company_id
    add_foreign_key :observable_moments, :people, column: :created_by_id
    add_foreign_key :observable_moments, :teammates, column: :primary_potential_observer_id
    add_foreign_key :observable_moments, :teammates, column: :processed_by_teammate_id
  end
end
