class AddSourceCheckInToAssignmentSurveyResponses < ActiveRecord::Migration[8.0]
  def change
    add_reference :assignment_survey_responses,
                  :source_assignment_check_in,
                  null: true,
                  foreign_key: { to_table: :assignment_check_ins },
                  index: {
                    unique: true,
                    where: "source_assignment_check_in_id IS NOT NULL",
                    name: "idx_asr_unique_source_assignment_check_in"
                  }
  end
end
