class GoalForm < Reform::Form
  # Define form properties - Reform handles Rails integration automatically
  property :title
  property :description
  property :goal_type
  property :earliest_target_date
  property :latest_target_date
  property :most_likely_target_date
  property :privacy_level
  property :owner_type
  property :owner_id
  property :started_at
  property :completed_at
  property :became_top_priority
  
  # Virtual property for timeframe selection (near_term, medium_term, long_term, vision)
  property :timeframe, virtual: true
  
  # Use ActiveModel validations for now - we can upgrade to dry-validation later
  validates :title, presence: true
  validates :goal_type, presence: true
  validates :privacy_level, presence: true
  # Target dates are optional
  validate :date_ordering
  validate :owner_selection
  validate :privacy_level_for_owner_type
  validate :goal_type_inclusion
  validate :privacy_level_inclusion
  
  # Override validate to parse owner selection before validations run
  def validate(*args)
    parse_owner_selection
    super
  end
  
  # Reform automatically handles save - we just need to customize the logic
  def save
    return false unless valid?
    
    # Set default most_likely_target_date based on timeframe if not explicitly set
    set_default_target_date_from_timeframe
    
    # Let Reform sync the form data to the model first
    super
    
    # Set creator to current_teammate
    if model.new_record?
      model.creator = current_teammate
    end
    
    # Set owner polymorphic association (already parsed in before_validation)
    model.owner_type = owner_type
    model.owner_id = owner_id
    
    # Save the model
    model.save
  end
  
  # Helper method to get current person (passed from controller)
  def current_person
    @current_person
  end
  
  # Helper method to set current person
  def current_person=(person)
    @current_person = person
  end
  
  # Helper method to get current teammate (passed from controller)
  def current_teammate
    @current_teammate
  end
  
  # Helper method to set current teammate
  def current_teammate=(teammate)
    @current_teammate = teammate
  end
  
  private
  
  def date_ordering
    # Only validate if all dates are present
    return unless earliest_target_date.present? && most_likely_target_date.present? && latest_target_date.present?
    
    if earliest_target_date > most_likely_target_date
      errors.add(:base, "earliest_target_date must be less than or equal to most_likely_target_date")
    end
    
    if most_likely_target_date > latest_target_date
      errors.add(:base, "most_likely_target_date must be less than or equal to latest_target_date")
    end
  end
  
  def owner_selection
    # If owner_id is provided as a string like "Teammate_123" or "Company_456", parse it
    # Otherwise, validate that both owner_type and owner_id are present
    if owner_id.is_a?(String) && owner_id.include?('_')
      # Already being parsed in parse_owner_selection
      return
    end
    
    unless owner_type.present? && owner_id.present?
      errors.add(:owner_id, "must be selected")
    end
  end
  
  def parse_owner_selection
    # Handle unified owner selection format: "Teammate_123", "Company_456", "Department_789", "Team_101"
    if owner_id.is_a?(String) && owner_id.include?('_')
      parts = owner_id.split('_', 2)
      self.owner_type = parts[0]
      self.owner_id = parts[1]
    end
  end
  
  def set_default_target_date_from_timeframe
    # Only set default if most_likely_target_date is not already set explicitly
    # If dates are explicitly set in advanced settings, they override timeframe selection
    return if most_likely_target_date.present?
    
    # Set based on timeframe selection if provided
    case timeframe
    when 'near_term'
      self.most_likely_target_date = Date.today + 90.days
    when 'medium_term'
      self.most_likely_target_date = Date.today + 270.days
    when 'long_term'
      self.most_likely_target_date = Date.today + 3.years
    when 'vision'
      # Vision goals don't have a target date
      self.most_likely_target_date = nil
    else
      # Default to 90 days if no timeframe is selected (for backwards compatibility)
      self.most_likely_target_date = Date.today + 90.days if model.new_record?
    end
  end
  
  def privacy_level_for_owner_type
    return unless owner_type && privacy_level
    
    # Rails polymorphic associations use the base class name for STI, so
    # Company/Department/Team all show up as "Organization" in owner_type after saving.
    # But in the form, we might still have "Company", "Department", or "Team" before saving.
    if owner_type.in?(['Company', 'Department', 'Team', 'Organization'])
      if privacy_level == 'only_creator_and_owner'
        errors.add(:privacy_level, 'is not valid for Organization owner')
      end
      # Note: only_creator_owner_and_managers IS valid for Organization owners
    end
  end
  
  def goal_type_inclusion
    return unless goal_type
    
    unless Goal.goal_types.key?(goal_type)
      errors.add(:goal_type, 'is not included in the list')
    end
  end
  
  def privacy_level_inclusion
    return unless privacy_level
    
    unless Goal.privacy_levels.key?(privacy_level)
      errors.add(:privacy_level, 'is not included in the list')
    end
  end
end

