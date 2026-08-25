class ReplaceFeedbackRequestAudienceWithOpenToAnyone < ActiveRecord::Migration[8.0]
  def up
    add_column :feedback_requests, :open_to_anyone, :boolean, null: false, default: true

    if column_exists?(:feedback_requests, :audience)
      execute <<-SQL.squish
        UPDATE feedback_requests
        SET open_to_anyone = CASE
          WHEN audience = 'specific_people' THEN FALSE
          ELSE TRUE
        END
      SQL
      remove_column :feedback_requests, :audience
    end
  end

  def down
    add_column :feedback_requests, :audience, :string, null: false, default: "specific_people"

    execute <<-SQL.squish
      UPDATE feedback_requests
      SET audience = CASE
        WHEN open_to_anyone THEN 'anyone_with_link'
        ELSE 'specific_people'
      END
    SQL

    remove_column :feedback_requests, :open_to_anyone
  end
end
