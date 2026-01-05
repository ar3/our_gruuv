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
  
  # Virtual property for story_extras (GIFs, etc.)
  property :story_extras, virtual: true
  
  # Virtual property for observable moment association
  property :observable_moment_id, virtual: true
  
  validates :story, presence: true, if: :publishing?
  validates :privacy_level, presence: true, unless: -> { observable_moment_id.present? }
  validates :primary_feeling, inclusion: { in: Feelings::FEELINGS.map { |f| f[:discrete_feeling].to_s } }, allow_nil: true, allow_blank: true
  validates :secondary_feeling, inclusion: { in: Feelings::FEELINGS.map { |f| f[:discrete_feeling].to_s } }, allow_nil: true, allow_blank: true
  validate :custom_slug_uniqueness
  
  def save
    return false unless valid?
    
    # Load and pre-fill from observable moment if present
    if observable_moment_id.present?
      observable_moment = ObservableMoment.find_by(id: observable_moment_id)
      if observable_moment
        # Pre-fill from moment context
        template_service = ObservableMoments::ObservationStoryTemplateService.new(observable_moment)
        
        # Pre-fill story if not already set
        self.story ||= template_service.template
        
        # Pre-fill observees if not already set
        if observees.empty?
          suggested_observees = template_service.suggested_observees
          suggested_observees.each do |teammate|
            observees << Observee.new(teammate: teammate)
          end
        end
        
        # Pre-fill privacy level if not already set
        self.privacy_level ||= template_service.suggested_privacy_level
        
        # Associate with observable moment
        model.observable_moment = observable_moment
      end
    end
    
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
    
    # Handle story_extras (GIFs, etc.)
    # Process story_extras if provided (even if empty hash)
    # story_extras is a virtual property, so it comes from params
    # Rails strong params may pass it as ActionController::Parameters
    # Note: Empty hash {} is still "present" in Rails, so we check for nil specifically
    # Also check if story_extras was explicitly passed (even if empty) by checking if it's a hash
    if !story_extras.nil? || (story_extras.is_a?(Hash) && story_extras.empty?)
      # story_extras comes as a hash like { "gif_urls" => ["url1", "url2"] }
      # or as nested params like { "gif_urls" => ["url1", "url2"] }
      # Convert ActionController::Parameters to hash if needed
      # ActionController::Parameters needs to be converted to hash to access values
      extras_hash = if story_extras.is_a?(ActionController::Parameters)
        # For permitted parameters, we can safely convert to hash
        story_extras.to_h
      elsif story_extras.is_a?(Hash)
        story_extras
      elsif story_extras.respond_to?(:to_h)
        story_extras.to_h
      else
        {}
      end
      
      # Ensure gif_urls is an array and filter out blanks
      # Check both string and symbol keys (ActionController::Parameters uses string keys)
      # Access the gif_urls array directly from the hash
      # If gif_urls key exists (even if empty), use it; otherwise default to empty array
      has_gif_urls_key = extras_hash.key?('gif_urls') || extras_hash.key?(:gif_urls)
      raw_gif_urls = if extras_hash.key?('gif_urls')
        extras_hash['gif_urls']
      elsif extras_hash.key?(:gif_urls)
        extras_hash[:gif_urls]
      else
        []
      end
      
      # Convert to array - if it's explicitly an empty array or nil with key present, keep it empty
      # Otherwise filter out blanks
      gif_urls = if raw_gif_urls.is_a?(Array)
        raw_gif_urls.empty? ? [] : raw_gif_urls.reject(&:blank?)
      elsif raw_gif_urls.nil? && has_gif_urls_key
        # Key exists but value is nil - Rails strong params may have filtered out empty array
        # Treat as empty array (user explicitly cleared all GIFs)
        []
      else
        Array(raw_gif_urls).reject(&:blank?)
      end
      
      # Build the story_extras hash - always set it, even if empty array
      # This ensures story_extras is saved even when all GIFs are removed
      model.story_extras = { 'gif_urls' => gif_urls }
    end
    # If story_extras is nil (not in params), don't change existing value
    # This preserves existing story_extras when form doesn't include it
    
    # Sync other form data to model (story, feelings, etc.)
    # Don't let Reform sync observation_ratings since we handled it manually above
    # Note: story_extras is handled separately above, so don't include it here
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
end
