class AddPersonalAlignmentToAssignmentSurveyResponses < ActiveRecord::Migration[8.0]
  def change
    add_column :assignment_survey_responses, :personal_alignment, :string
    add_check_constraint :assignment_survey_responses,
      "personal_alignment IS NULL OR personal_alignment IN ('love', 'like', 'neutral', 'prefer_not', 'only_if_necessary')",
      name: "assignment_survey_responses_personal_alignment_check"
  end
end
