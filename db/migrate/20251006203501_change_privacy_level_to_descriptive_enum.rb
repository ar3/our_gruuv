class ChangePrivacyLevelToDescriptiveEnum < ActiveRecord::Migration[8.0]
  def up
    # First, add a temporary string column
    add_column :observations, :privacy_level_string, :string
    
    # Migrate existing data from integer to string
    execute <<-SQL
      UPDATE observations 
      SET privacy_level_string = CASE privacy_level
        WHEN 0 THEN 'observer_only'
        WHEN 1 THEN 'observed_only'
        WHEN 2 THEN 'managers_only'
        WHEN 3 THEN 'observed_and_managers'
        WHEN 4 THEN 'public_observation'
        ELSE 'observer_only'
      END
    SQL
    
    # Remove the old integer column
    remove_column :observations, :privacy_level
    
    # Rename the new column to the original name
    rename_column :observations, :privacy_level_string, :privacy_level
    
    # Add not null constraint and default
    change_column_null :observations, :privacy_level, false
    change_column_default :observations, :privacy_level, 'observer_only'
  end

  def down
    # Add a temporary integer column
    add_column :observations, :privacy_level_int, :integer
    
    # Migrate existing data from string to integer
    execute <<-SQL
      UPDATE observations 
      SET privacy_level_int = CASE privacy_level
        WHEN 'observer_only' THEN 0
        WHEN 'observed_only' THEN 1
        WHEN 'managers_only' THEN 2
        WHEN 'observed_and_managers' THEN 3
        WHEN 'public_observation' THEN 4
        ELSE 0
      END
    SQL
    
    # Remove the string column
    remove_column :observations, :privacy_level
    
    # Rename the integer column to the original name
    rename_column :observations, :privacy_level_int, :privacy_level
    
    # Add not null constraint and default
    change_column_null :observations, :privacy_level, false
    change_column_default :observations, :privacy_level, 0
  end
end