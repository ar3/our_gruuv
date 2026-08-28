class DropAssignmentSurveySubmissions < ActiveRecord::Migration[8.0]
  def up
    remove_index :assignment_survey_responses,
                 name: "index_assignment_survey_responses_on_submission_assignment",
                 if_exists: true

    if column_exists?(:assignment_survey_responses, :assignment_survey_submission_id)
      remove_reference :assignment_survey_responses, :assignment_survey_submission, foreign_key: true
    end

    drop_table :assignment_survey_submissions, if_exists: true
  end

  def down
    create_table :assignment_survey_submissions do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :teammate, null: false, foreign_key: { to_table: :teammates }
      t.string :status, null: false, default: "draft"
      t.datetime :finalized_at
      t.timestamps
    end

    add_index :assignment_survey_submissions,
              :teammate_id,
              unique: true,
              where: "status = 'draft'",
              name: "index_assignment_survey_submissions_on_one_draft_per_teammate"
    add_index :assignment_survey_submissions,
              [ :organization_id, :teammate_id, :finalized_at ],
              name: "index_assignment_survey_submissions_for_latest_results"
    add_check_constraint :assignment_survey_submissions,
                         "status IN ('draft', 'finalized')",
                         name: "assignment_survey_submissions_status_check"

    add_reference :assignment_survey_responses,
                  :assignment_survey_submission,
                  null: true,
                  foreign_key: true,
                  index: { name: "index_assignment_survey_responses_on_submission_id" }
    add_index :assignment_survey_responses,
              [ :assignment_survey_submission_id, :assignment_id ],
              unique: true,
              name: "index_assignment_survey_responses_on_submission_assignment"

    say "Down migration recreates assignment_survey_submissions and the response FK column only; rows are not restored."
  end
end
