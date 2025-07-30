class PositionLevel < ApplicationRecord
  belongs_to :position_major_level

  validates :level, presence: true
  validates :level, uniqueness: { scope: :position_major_level_id }
  validates :level, format: { with: /\A\d+\.\d+\z/, message: "must be in format 'major.minor' (e.g., '1.1', '2.3')" }
end
