# frozen_string_literal: true

class AssignmentClarityResult < ApplicationRecord
  include OgConsultations::MarkdownClarityResult

  has_many :assignment_clarity_recommendation_acceptances, dependent: :destroy

  validates :clarity_score,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
            allow_nil: true
end
