class ObservationForm < Reform::Form
  include Reform::Form::ActiveModel::Validations
  
  property :story
  property :privacy_level
  property :primary_feeling
  property :secondary_feeling
  property :observed_at
  property :custom_slug
  # Virtual state: publishing vs draft saves
  property :publishing, virtual: true
  
  # Nested attributes for observees
  collection :observees, populate_if_empty: Observee do
    property :teammate_id
    property :_destroy, virtual: true
  end
  
  # Nested attributes for observation ratings
  collection :observation_ratings, populate_if_empty: ObservationRating do
    property :id
    property :rateable_type
    property :rateable_id
    property :rating
    property :_destroy, virtual: true
    
    # Note: Duplicate prevention is handled in the save method, not via validation
    # because nested collection validations don't have easy access to parent model
  end
  
  # Virtual properties for handling teammate_ids from form
  property :teammate_ids, virtual: true
  
  # Virtual property for observation ratings attributes (used in wizard)
  property :observation_ratings_attributes, virtual: true
  
  validates :story, presence: true, if: :publishing?
  validates :privacy_level, presence: true
  validates :primary_feeling, inclusion: { in: Feelings::FEELINGS.map { |f| f[:discrete_feeling].to_s } }, allow_nil: true, allow_blank: true
  validates :secondary_feeling, inclusion: { in: Feelings::FEELINGS.map { |f| f[:discrete_feeling].to_s } }, allow_nil: true, allow_blank: true
  validate :custom_slug_uniqueness
  validate :at_least_one_observee
  
  def save
    return false unless valid?
    
    # Story can be nil for drafts (migration allows it)
    # Validation only requires it for published observations
    
    # Save the model first if it's new (needed for associations)
    model.save! if model.new_record?
    
    # Manually handle observation_ratings to prevent duplicates
    # Reform collections can create duplicates if not handled carefully
    # We need to handle this manually to check for existing ratings
    if observation_ratings.any?
      observation_ratings.each do |rating_form|
        next if rating_form._destroy == true || rating_form._destroy == '1'
        next unless rating_form.rateable_type.present? && rating_form.rateable_id.present?
        
        # Ensure model is saved before checking for existing ratings
        model.save! if model.new_record? || model.changed?
        
        # Check if rating already exists (by rateable, not by id since new records won't have id yet)
        existing_rating = model.observation_ratings.find_by(
          rateable_type: rating_form.rateable_type,
          rateable_id: rating_form.rateable_id
        )
        
        if existing_rating
          # Update existing rating (if rating value provided, otherwise keep existing)
          if rating_form.rating.present?
            existing_rating.update!(rating: rating_form.rating)
          end
        else
          # Create new rating only if it doesn't exist
          model.observation_ratings.create!(
            rateable_type: rating_form.rateable_type,
            rateable_id: rating_form.rateable_id,
            rating: rating_form.rating
          )
        end
      end
    end
    
    # Sync other form data to model (story, feelings, etc.)
    # Don't let Reform sync observation_ratings since we handled it manually above
    model.assign_attributes(
      story: story,
      privacy_level: privacy_level,
      primary_feeling: primary_feeling,
      secondary_feeling: secondary_feeling,
      observed_at: observed_at,
      custom_slug: custom_slug
    )
    
    # Save model with other attributes
    model.save!
  end

  def publishing?
    publishing == true || publishing.to_s == 'true'
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
