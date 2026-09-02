# frozen_string_literal: true

class AssignmentExpectationAlignmentScore < ApplicationRecord
  belongs_to :assignment
  belongs_to :organization

  validates :assignment_id, uniqueness: true
  validates :calculated_at, presence: true
  validates :check_in_teammate_count, :survey_respondent_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def threshold_met?
    check_in_teammate_count >= AssignmentSurveys::ExpectationAlignmentScore::PUBLIC_EMPLOYEE_THRESHOLD ||
      survey_respondent_count >= AssignmentSurveys::ExpectationAlignmentScore::PUBLIC_EMPLOYEE_THRESHOLD
  end
end
