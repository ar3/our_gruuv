class RemoveStateFromFeedbackRequests < ActiveRecord::Migration[8.0]
  def change
    remove_column :feedback_requests, :state, :integer
  end
end
