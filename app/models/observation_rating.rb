class ObservationRating < ApplicationRecord
  belongs_to :observation
  belongs_to :rateable, polymorphic: true

  # Single source of truth for human-facing OGO rating labels.
  # Change a value here to rename a rating everywhere in the app.
  DISPLAY_LABELS = {
    'strongly_agree' => 'Exceptional',
    'agree' => 'Strong',
    'na' => 'N/A',
    'disagree' => 'Mis-aligned',
    'strongly_disagree' => 'Concerning'
  }.freeze

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

  def self.display_label(rating)
    DISPLAY_LABELS.fetch(rating.to_s) { rating.to_s.humanize }
  end

  def self.label_to_rating
    @label_to_rating ||= DISPLAY_LABELS.invert.freeze
  end

  def display_label
    self.class.display_label(rating)
  end

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
