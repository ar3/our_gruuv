class CreateFeedbackRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :feedback_requests do |t|
      t.references :company, null: false, foreign_key: { to_table: :organizations }
      t.references :requestor_teammate, null: false, foreign_key: { to_table: :teammates }
      t.references :subject_of_feedback_teammate, null: false, foreign_key: { to_table: :teammates }
      t.references :assignment, null: true, foreign_key: true
      t.references :ability, null: true, foreign_key: true
      t.references :aspiration, null: true, foreign_key: true
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :feedback_requests, :company_id, if_not_exists: true
    add_index :feedback_requests, :requestor_teammate_id, if_not_exists: true
    add_index :feedback_requests, :subject_of_feedback_teammate_id, if_not_exists: true
    add_index :feedback_requests, :assignment_id, if_not_exists: true
    add_index :feedback_requests, :ability_id, if_not_exists: true
    add_index :feedback_requests, :aspiration_id, if_not_exists: true
    add_index :feedback_requests, :deleted_at, if_not_exists: true
  end
end
