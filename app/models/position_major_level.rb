class PositionMajorLevel < ApplicationRecord
  validates :major_level, presence: true
  validates :set_name, presence: true
  validates :major_level, uniqueness: { scope: :set_name }
end
