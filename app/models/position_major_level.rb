class PositionMajorLevel < ApplicationRecord
  has_many :position_levels, dependent: :destroy
  has_many :titles, dependent: :restrict_with_exception

  validates :major_level, presence: true
  validates :set_name, presence: true
  validates :major_level, uniqueness: { scope: :set_name }

  def to_s
    "#{set_name} – #{major_level} – #{description.present? ? description[0..200] : ''}"
  end

  def display_name
    "L:#{major_level}.* (#{set_name})"
  end
end
