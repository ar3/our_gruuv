class PositionMajorLevel < ApplicationRecord
  has_many :position_levels, dependent: :destroy
  has_many :titles, dependent: :restrict_with_exception

  validates :major_level, presence: true
  validates :set_name, presence: true
  validates :major_level, uniqueness: { scope: :set_name }

  # UI label without set_name — set names are only surfaced on the Position levels page.
  def to_s
    desc = description.present? ? description[0..200] : nil
    [display_name, desc].compact.join(" – ")
  end

  def display_name
    "L:#{major_level}.*"
  end
end
