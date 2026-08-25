class AddAudienceToFeedbackRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :feedback_requests, :audience, :string, null: false, default: "specific_people"
  end
end
