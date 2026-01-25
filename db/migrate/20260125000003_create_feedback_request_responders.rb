class CreateFeedbackRequestResponders < ActiveRecord::Migration[8.0]
  def change
    create_table :feedback_request_responders do |t|
      t.references :feedback_request, null: false, foreign_key: true
      t.references :teammate, null: false, foreign_key: true

      t.timestamps
    end

    add_index :feedback_request_responders, :feedback_request_id, if_not_exists: true
    add_index :feedback_request_responders, :teammate_id, if_not_exists: true
    add_index :feedback_request_responders, [:feedback_request_id, :teammate_id], unique: true, name: 'index_feedback_request_responders_on_request_and_teammate'
  end
end
