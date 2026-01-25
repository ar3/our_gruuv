class AddStateToFeedbackRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :feedback_requests, :state, :integer, default: 0, null: false
  end
end
