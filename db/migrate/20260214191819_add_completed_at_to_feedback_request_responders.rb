class AddCompletedAtToFeedbackRequestResponders < ActiveRecord::Migration[8.0]
  def change
    add_column :feedback_request_responders, :completed_at, :datetime
  end
end
