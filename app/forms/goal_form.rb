class GoalForm < Reform::Form
  # Define form properties - Reform handles Rails integration automatically
  property :title
  property :description
  property :goal_type
  property :earliest_target_date
  property :latest_target_date
  property :most_likely_target_date
  property :privacy_level
  property :initial_confidence
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
  validate :owner_exists
  validate :owner_type_valid
  validate :privacy_level_for_owner_type
  validate :goal_type_inclusion
  validate :privacy_level_inclusion
  validate :initial_confidence_inclusion
  validate :current_teammate_present_for_new_goals
  
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
    
    # Set creator before Reform persists (super syncs + model.save); otherwise creator_id is null at save (OURGRUUV-178)
    if model.new_record? && current_teammate.present?
      model.creator = current_teammate
    end
    
    # Let Reform sync the form data to the model and persist
    super
    
    # Set owner polymorphic association (already parsed in before_validation)
    # Only allow CompanyTeammate, Company, Department, or Team as owner types
    # Goal model stores Organization (not Company); normalize for validation
    model.owner_type = (owner_type == 'Company' ? 'Organization' : owner_type)
    model.owner_id = owner_id
    
    # Save the model
    if model.save
      true
    else
      # Copy model errors to form errors so they're displayed
      model.errors.each do |error|
        errors.add(error.attribute, error.message)
      end
      false
    end
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
    # If owner_id is provided as a string like "CompanyTeammate_123" or "Company_456", parse it
    # Otherwise, validate that both owner_type and owner_id are present
    # Note: parse_owner_selection is called before this validation, so if owner was nil/blank,
    # it should have been set to current_teammate already
    if owner_id.is_a?(String) && owner_id.include?('_')
      # Already being parsed in parse_owner_selection
      return
    end
    
    # If owner is still not set after parse_owner_selection, that means current_teammate is nil
    # In that case, we can't automatically set it, so we need to show an error
    unless owner_type.present? && owner_id.present?
      errors.add(:owner_id, "must be selected")
    end
  end
  
  def parse_owner_selection
    # Handle unified owner selection format: "CompanyTeammate_123", "Company_456", "Department_789", "Team_101"
    if owner_id.is_a?(String) && owner_id.include?('_')
      parts = owner_id.split('_', 2)
      parsed_type = parts[0]
      # Reject 'Teammate' - it must be 'CompanyTeammate'
      if parsed_type == 'Teammate'
        errors.add(:owner_id, 'must be CompanyTeammate, not Teammate')
        return
      end
      self.owner_type = parsed_type
      self.owner_id = parts[1]
    end
    
    # If owner is nil or blank, automatically set it to current_teammate
    # Check both nil and blank (empty string) cases
    if (owner_type.nil? || owner_type.blank? || owner_id.nil? || owner_id.blank?) && current_teammate
      self.owner_type = 'CompanyTeammate'
      self.owner_id = current_teammate.id.to_s
    end
  end
  
  def set_default_target_date_from_timeframe
    # Only set default if most_likely_target_date is not already set explicitly
    # If dates are explicitly set in advanced settings, they override timeframe selection
    return if most_likely_target_date.present?
    # When user chose "Custom" timeframe, use their date fields; do not apply preset defaults
    return if timeframe == 'custom'

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
    
    # Company/Department/Team owners have restricted privacy options
    if owner_type.in?(['Company', 'Department', 'Team'])
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

  def initial_confidence_inclusion
    return if initial_confidence.blank?

    unless Goal.initial_confidences.key?(initial_confidence)
      errors.add(:initial_confidence, 'is not included in the list')
    end
  end

  def current_teammate_present_for_new_goals
    return unless model.new_record?
    return if current_teammate.present? && !current_teammate.destroyed?

    errors.add(:base, 'You must be a company teammate to create goals')
  end
  
  def owner_exists
    return unless owner_type && owner_id
    
    # Parse owner if it's in the unified format
    parse_owner_selection if owner_id.is_a?(String) && owner_id.include?('_')
    
    return unless owner_type && owner_id
    
    # Reject 'Teammate' - it must be 'CompanyTeammate'
    if owner_type == 'Teammate'
      # Error will be added in owner_type_valid
      return
    end
    
    # Only allow CompanyTeammate, Company, Department, or Team as owner types
    unless owner_type.in?(['CompanyTeammate', 'Company', 'Department', 'Team'])
      # Error will be added in owner_type_valid
      return
    end
    
    # Load the owner to check if it exists
    owner = case owner_type
            when 'CompanyTeammate'
              CompanyTeammate.find_by(id: owner_id)
            when 'Company', 'Department', 'Team'
              Organization.find_by(id: owner_id)
            end
    
    unless owner
      errors.add(:owner_id, 'must exist')
    end
  end
  
  def owner_type_valid
    return unless owner_type && owner_id
    
    # Parse owner if it's in the unified format
    parse_owner_selection if owner_id.is_a?(String) && owner_id.include?('_')
    
    return unless owner_type && owner_id
    
    # Reject 'Teammate' - it must be 'CompanyTeammate'
    if owner_type == 'Teammate'
      errors.add(:owner_id, 'must be CompanyTeammate, not Teammate')
      return
    end
    
    # Only allow CompanyTeammate, Company, Department, or Team as owner types
    unless owner_type.in?(['CompanyTeammate', 'Company', 'Department', 'Team'])
      errors.add(:owner_type, 'must be CompanyTeammate, Company, Department, or Team')
      return
    end
    
    # Load the owner to validate its type
    owner = case owner_type
            when 'CompanyTeammate'
              CompanyTeammate.find_by(id: owner_id)
            when 'Company', 'Department', 'Team'
              Organization.find_by(id: owner_id)
            end
    
    return unless owner
    
    if owner_type == 'CompanyTeammate'
      unless owner.is_a?(CompanyTeammate)
        errors.add(:owner_id, 'must be a CompanyTeammate')
      end
    elsif owner_type.in?(['Company', 'Department', 'Team'])
      # Organization (company), Department, or Team
      unless owner.is_a?(Organization) || owner.is_a?(Department) || owner.is_a?(Team)
        errors.add(:owner_id, 'must be a Department, Team, or Organization')
      end
    end
  end
end

