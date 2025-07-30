class PositionMajorLevel < ApplicationRecord
  has_many :position_levels, dependent: :destroy

  validates :major_level, presence: true
  validates :set_name, presence: true
  validates :major_level, uniqueness: { scope: :set_name }
end
