# frozen_string_literal: true

class TitleExpectationAlignmentScore < ApplicationRecord
  belongs_to :title
  belongs_to :organization

  validates :title_id, uniqueness: true
  validates :calculated_at, presence: true
end
