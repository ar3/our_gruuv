class AddObservationTriggerIdToObservations < ActiveRecord::Migration[8.0]
  def change
    add_reference :observations, :observation_trigger, null: true, foreign_key: true
  end
end
