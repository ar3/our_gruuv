# frozen_string_literal: true

# Expand step: add audience beside open_to_anyone. Dual-write in the app keeps them
# in sync until a later deploy drops open_to_anyone.
class AddAudienceEnumToFeedbackRequests < ActiveRecord::Migration[8.0]
  def up
    add_column :feedback_requests, :audience, :string, null: false, default: "organization"

    execute <<-SQL.squish
      UPDATE feedback_requests
      SET audience = CASE
        WHEN open_to_anyone THEN 'organization'
        ELSE 'recipients_only'
      END
    SQL
  end

  def down
    remove_column :feedback_requests, :audience
  end
end
