class ResponsesOnlyAssignmentSurvey < ActiveRecord::Migration[8.0]
  def up
    add_reference :assignment_survey_responses, :teammate, foreign_key: true
    add_reference :assignment_survey_responses, :organization, foreign_key: true
    add_column :assignment_survey_responses, :submitted_at, :datetime

    backfill_responses_from_submissions

    change_column_null :assignment_survey_responses, :teammate_id, false
    change_column_null :assignment_survey_responses, :organization_id, false

    add_index :assignment_survey_responses,
              [ :teammate_id, :assignment_id ],
              unique: true,
              where: "submitted_at IS NULL",
              name: "idx_asr_one_in_progress_per_assignment"
    add_index :assignment_survey_responses,
              [ :organization_id, :teammate_id, :submitted_at ],
              name: "idx_asr_org_teammate_submitted"

    # Keep assignment_survey_submission_id and assignment_survey_submissions for
    # post-deploy verification. Removed in db/migrate/20260828040000_drop_assignment_survey_submissions.rb
  end

  def down
    remove_index :assignment_survey_responses, name: "idx_asr_org_teammate_submitted"
    remove_index :assignment_survey_responses, name: "idx_asr_one_in_progress_per_assignment"

    change_column_null :assignment_survey_responses, :teammate_id, true
    change_column_null :assignment_survey_responses, :organization_id, true
    remove_reference :assignment_survey_responses, :teammate, foreign_key: true
    remove_reference :assignment_survey_responses, :organization, foreign_key: true
    remove_column :assignment_survey_responses, :submitted_at
  end

  private

  def backfill_responses_from_submissions
    say_with_time "Backfilling assignment survey responses from submissions" do
      execute <<~SQL.squish
        UPDATE assignment_survey_responses AS responses
        SET teammate_id = submissions.teammate_id,
            organization_id = submissions.organization_id,
            submitted_at = CASE
              WHEN submissions.status = 'finalized' THEN submissions.finalized_at
              ELSE NULL
            END
        FROM assignment_survey_submissions AS submissions
        WHERE responses.assignment_survey_submission_id = submissions.id
      SQL
    end
  end
end
