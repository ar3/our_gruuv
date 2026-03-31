class PositionLevel < ApplicationRecord
  belongs_to :position_major_level
  has_many :positions, dependent: :destroy

  validates :level, presence: true
  validates :level, uniqueness: { scope: :position_major_level_id }
  validates :level, format: { with: /\A\d+\.\d+\z/, message: "must be in format 'major.minor' (e.g., '1.1', '2.3')" }
  
  # Instance methods
  def display_name
    "#{position_major_level.major_level}.#{level}"
  end
  
  def level_name
    level
  end

  # Minor segment of "major.minor" must be 1, 2, or 3 for eligibility cascade FKs.
  ELIGIBILITY_MINOR_RANGE = (1..3).freeze

  def eligibility_minor_slot
    m = level.to_s.match(/\A\d+\.(\d+)\z/)
    raise ArgumentError, "Invalid position level format: #{level.inspect}" if m.blank?

    n = m[1].to_i
    raise ArgumentError, "Position level minor must be 1, 2, or 3 (got #{n})" unless ELIGIBILITY_MINOR_RANGE.cover?(n)

    n
  end
end
