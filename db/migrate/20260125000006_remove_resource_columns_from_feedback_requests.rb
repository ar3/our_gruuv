class RemoveResourceColumnsFromFeedbackRequests < ActiveRecord::Migration[8.0]
  def change
    remove_reference :feedback_requests, :assignment, foreign_key: true, if_exists: true
    remove_reference :feedback_requests, :ability, foreign_key: true, if_exists: true
    remove_reference :feedback_requests, :aspiration, foreign_key: true, if_exists: true
  end
end
