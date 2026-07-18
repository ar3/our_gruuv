# frozen_string_literal: true

class AssignmentClarityRecommendationAcceptance < ApplicationRecord
  belongs_to :assignment_clarity_result
  belongs_to :teammate, class_name: 'CompanyTeammate'

  validates :recommendation_id, presence: true
end
