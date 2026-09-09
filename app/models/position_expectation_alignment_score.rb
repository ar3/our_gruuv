# frozen_string_literal: true

class PositionExpectationAlignmentScore < ApplicationRecord
  belongs_to :position
  belongs_to :organization

  validates :position_id, uniqueness: true
  validates :calculated_at, presence: true
  validates :required_assignments_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
