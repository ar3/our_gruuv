# frozen_string_literal: true

# Contract step: stable public share token + drop open_to_anyone (audience is source of truth).
class AddPublicAnswerTokenAndRemoveOpenToAnyone < ActiveRecord::Migration[8.0]
  def up
    add_column :feedback_requests, :public_answer_token, :string
    add_index :feedback_requests, :public_answer_token, unique: true

    say_with_time "backfill public_answer_token" do
      FeedbackRequest.reset_column_information
      FeedbackRequest.unscoped.find_each do |fr|
        fr.update_columns(public_answer_token: SecureRandom.base58(24))
      end
    end

    change_column_null :feedback_requests, :public_answer_token, false
    remove_column :feedback_requests, :open_to_anyone, :boolean
  end

  def down
    add_column :feedback_requests, :open_to_anyone, :boolean, null: false, default: true

    execute <<-SQL.squish
      UPDATE feedback_requests
      SET open_to_anyone = CASE
        WHEN audience = 'recipients_only' THEN FALSE
        ELSE TRUE
      END
    SQL

    remove_index :feedback_requests, :public_answer_token
    remove_column :feedback_requests, :public_answer_token
  end
end
