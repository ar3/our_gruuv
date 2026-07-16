class CreateAssignmentSurveySubmissionsAndResponses < ActiveRecord::Migration[8.0]
  def change
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

    create_table :assignment_survey_responses do |t|
      t.references :assignment_survey_submission,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_assignment_survey_responses_on_submission_id" }
      t.references :assignment, null: false, foreign_key: true
      t.string :assignment_source, null: false
      t.string :snapshot_title, null: false
      t.text :snapshot_tagline
      t.text :snapshot_required_activities
      t.jsonb :snapshot_outcomes, null: false, default: []
      t.integer :understandable_rating
      t.integer :possible_rating
      t.integer :relevant_rating
      t.text :comment
      t.timestamps
    end

    add_index :assignment_survey_responses,
              [ :assignment_survey_submission_id, :assignment_id ],
              unique: true,
              name: "index_assignment_survey_responses_on_submission_assignment"
    add_check_constraint :assignment_survey_responses,
                         "assignment_source IN ('active', 'required', 'active_and_required')",
                         name: "assignment_survey_responses_source_check"

    %i[understandable_rating possible_rating relevant_rating].each do |column|
      add_check_constraint :assignment_survey_responses,
                           "#{column} BETWEEN 1 AND 6",
                           name: "assignment_survey_responses_#{column}_check"
    end
  end
end
