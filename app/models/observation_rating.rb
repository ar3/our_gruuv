class ObservationRating < ApplicationRecord
  belongs_to :observation
  belongs_to :rateable, polymorphic: true
  
  enum :rating, {
    strongly_disagree: 'strongly_disagree',
    disagree: 'disagree',
    na: 'na',
    agree: 'agree',
    strongly_agree: 'strongly_agree'
  }
  
  validates :observation, :rateable, :rating, presence: true
  validates :rateable_id, uniqueness: { scope: [:observation_id, :rateable_type] }
  validates :rateable_type, inclusion: { in: %w[Ability Assignment Aspiration] }
  
  scope :positive, -> { where(rating: [:strongly_agree, :agree]) }
  scope :negative, -> { where(rating: [:disagree, :strongly_disagree]) }
  scope :neutral, -> { where(rating: :na) }
  scope :for_rateable, ->(rateable) { where(rateable: rateable) }
  scope :by_rating, ->(rating) { where(rating: rating) }
  
  def positive?
    strongly_agree? || agree?
  end
  
  def negative?
    disagree? || strongly_disagree?
  end
  
  def neutral?
    na?
  end
end
