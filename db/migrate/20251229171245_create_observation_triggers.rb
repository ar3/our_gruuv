class CreateObservationTriggers < ActiveRecord::Migration[8.0]
  def change
    create_table :observation_triggers do |t|
      t.string :trigger_source, null: false
      t.string :trigger_type, null: false
      t.jsonb :trigger_data, default: {}, null: false

      t.timestamps
    end
    
    add_index :observation_triggers, [:trigger_source, :trigger_type]
    add_index :observation_triggers, :trigger_data, using: :gin
  end
end
