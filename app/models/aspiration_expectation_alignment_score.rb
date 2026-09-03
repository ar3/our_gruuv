# frozen_string_literal: true

class AspirationExpectationAlignmentScore < ApplicationRecord
  belongs_to :aspiration
  belongs_to :organization

  validates :aspiration_id, uniqueness: true
  validates :calculated_at, presence: true
  validates :check_in_teammate_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def threshold_met?
    check_in_teammate_count >= Aspirations::ExpectationAlignmentScore::PUBLIC_EMPLOYEE_THRESHOLD
  end
end
