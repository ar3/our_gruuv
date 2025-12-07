class AddPublicToCompanyPrivacyLevelToObservations < ActiveRecord::Migration[8.0]
  def up
    # Migrate all existing public_observation records to public_to_world
    execute <<-SQL
      UPDATE observations 
      SET privacy_level = 'public_to_world'
      WHERE privacy_level = 'public_observation'
    SQL
  end

  def down
    # Migrate public_to_world back to public_observation
    execute <<-SQL
      UPDATE observations 
      SET privacy_level = 'public_observation'
      WHERE privacy_level = 'public_to_world'
    SQL
  end
end
