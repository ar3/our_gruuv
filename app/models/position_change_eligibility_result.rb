# frozen_string_literal: true

class PositionChangeEligibilityResult < ApplicationRecord
  CHANGE_TYPES = %w[same_position intra_title title_change].freeze

  belongs_to :og_consultation
  belongs_to :position

  validates :change_type, inclusion: { in: CHANGE_TYPES }, allow_nil: true
end
