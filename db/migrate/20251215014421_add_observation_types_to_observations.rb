class AddObservationTypesToObservations < ActiveRecord::Migration[8.0]
  def change
    add_column :observations, :observation_type, :string, default: 'generic', null: false
    add_column :observations, :created_as_type, :string
    
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE observations 
          SET created_as_type = 'generic' 
          WHERE created_as_type IS NULL
        SQL
      end
    end
    
    add_index :observations, :observation_type
    add_index :observations, :created_as_type
  end
end
