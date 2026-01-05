class AddObservableMomentToObservations < ActiveRecord::Migration[8.0]
  def change
    add_reference :observations, :observable_moment, foreign_key: true, index: true
  end
end
