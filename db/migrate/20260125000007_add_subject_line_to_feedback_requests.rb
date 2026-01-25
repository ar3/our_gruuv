class AddSubjectLineToFeedbackRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :feedback_requests, :subject_line, :string
  end
end
