class PositionMajorLevel < ApplicationRecord
  has_many :position_levels, dependent: :destroy

  validates :major_level, presence: true
  validates :set_name, presence: true
  validates :major_level, uniqueness: { scope: :set_name }

  def to_s
    "#{set_name} – #{major_level} – #{description.present? ? description[0..200] : ''}"
  end
end
