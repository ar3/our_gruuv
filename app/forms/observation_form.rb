class ObservationForm < Reform::Form
  include Reform::Form::ActiveModel::Validations
  
  property :story
  property :privacy_level
  property :primary_feeling
  property :secondary_feeling
  property :observed_at
  property :custom_slug
  
  # Nested attributes for observees
  collection :observees, populate_if_empty: Observee do
    property :teammate_id
    property :_destroy, virtual: true
  end
  
  # Nested attributes for observation ratings
  collection :observation_ratings, populate_if_empty: ObservationRating do
    property :rateable_type
    property :rateable_id
    property :rating
    property :_destroy, virtual: true
  end
  
  # Virtual properties for handling teammate_ids from form
  property :teammate_ids, virtual: true
  
  # Virtual property for observation ratings attributes (used in wizard)
  property :observation_ratings_attributes, virtual: true
  
  validates :story, presence: true
  validates :privacy_level, presence: true
  validates :primary_feeling, inclusion: { in: Feelings::FEELINGS.map { |f| f[:discrete_feeling].to_s } }, allow_nil: true, allow_blank: true
  validates :secondary_feeling, inclusion: { in: Feelings::FEELINGS.map { |f| f[:discrete_feeling].to_s } }, allow_nil: true, allow_blank: true
  validate :custom_slug_uniqueness
  validate :at_least_one_observee
  
  def save
    return false unless valid?
    super
  end

  # Normalize empty strings to nil for feelings
  def primary_feeling=(value)
    super(value.present? ? value : nil)
  end

  def secondary_feeling=(value)
    super(value.present? ? value : nil)
  end
  
  # Getter for observation_ratings_attributes
  def observation_ratings_attributes
    @observation_ratings_attributes ||= {}
  end
  
  # Setter for observation_ratings_attributes
  def observation_ratings_attributes=(value)
    @observation_ratings_attributes = value
  end
  
  # Helper method to safely format observed_at for datetime input
  def observed_at_for_input
    return Time.current.strftime('%Y-%m-%dT%H:%M') if observed_at.blank?
    
    if observed_at.is_a?(Time)
      observed_at.strftime('%Y-%m-%dT%H:%M')
    else
      Time.parse(observed_at.to_s).strftime('%Y-%m-%dT%H:%M')
    end
  rescue
    Time.current.strftime('%Y-%m-%dT%H:%M')
  end
  
  private
  
  def custom_slug_uniqueness
    return if custom_slug.blank?
    
    existing_observation = Observation.where(custom_slug: custom_slug).where.not(id: model.id).first
    if existing_observation
      errors.add(:custom_slug, 'has already been taken')
    end
  end
  
  def at_least_one_observee
    # Check both existing observees and virtual properties
    # Filter out empty strings from teammate_ids (Rails checkbox behavior)
    valid_teammate_ids = teammate_ids&.reject(&:blank?) || []
    has_observees = observees.any? || valid_teammate_ids.any?
    errors.add(:observees, "must have at least one observee") unless has_observees
  end
end
