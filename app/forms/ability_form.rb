class AbilityForm < Reform::Form
  # Define form properties - Reform handles Rails integration automatically
  property :name
  property :description
  property :company_id
  property :department_id
  property :version_type, virtual: true  # This is a form-only field, not on the model
  property :milestone_1_description
  property :milestone_2_description
  property :milestone_3_description
  property :milestone_4_description
  property :milestone_5_description

  # Use ActiveModel validations for now - we can upgrade to dry-validation later
  validates :name, presence: true
  validates :description, presence: true
  validates :company_id, presence: true
  validates :version_type, presence: true, unless: :new_form_without_data?
  validate :at_least_one_milestone_description
  validate :version_type_for_context
  validate :form_data_present

  # Reform automatically handles save - we just need to customize the logic
  def save
    return false unless valid?
    
    # Let Reform sync the form data to the model first
    super
    
    # Set the semantic version based on version type
    model.semantic_version = calculate_semantic_version
    
    # Set audit fields
    model.created_by = current_person if model.new_record?
    model.updated_by = current_person
    
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

  private

  def new_form_without_data?
    # Don't validate version_type on initial page load (new action)
    # Only validate when form has been submitted with data
    model.new_record? && !@form_data_empty.nil? && @form_data_empty
  end

  def form_data_present
    # Check if any form fields have been provided
    # This validation only runs when no ability parameters are provided at all
    if @form_data_empty
      errors.add(:base, "Form data is missing. Please fill out the form and try again.")
    end
  end

  def at_least_one_milestone_description
    milestone_descriptions = [
      milestone_1_description,
      milestone_2_description,
      milestone_3_description,
      milestone_4_description,
      milestone_5_description
    ]
    
    if milestone_descriptions.all?(&:blank?)
      errors.add(:milestone_descriptions, "At least one milestone description is required")
    end
  end

  def version_type_for_context
    return unless version_type.present?
    
    if model.persisted?
      # For existing abilities, only allow update types
      unless %w[fundamental clarifying insignificant].include?(version_type)
        errors.add(:version_type, "must be fundamental, clarifying, or insignificant for existing abilities")
      end
    else
      # For new abilities, only allow creation types
      unless %w[ready nearly_ready early_draft].include?(version_type)
        errors.add(:version_type, "must be ready, nearly ready, or early draft for new abilities")
      end
    end
  end

  def calculate_semantic_version
    if model.persisted?
      calculate_version_for_existing_ability
    else
      calculate_version_for_new_ability
    end
  end

  def calculate_version_for_new_ability
    case version_type
    when 'ready'
      "1.0.0"
    when 'nearly_ready'
      "0.1.0"
    when 'early_draft'
      "0.0.1"
    else
      "0.0.1"  # Default to early draft
    end
  end

  def calculate_version_for_existing_ability
    return model.semantic_version unless model.semantic_version.present?

    major, minor, patch = model.semantic_version.split('.').map(&:to_i)

    case version_type
    when 'fundamental'
      "#{major + 1}.0.0"
    when 'clarifying'
      "#{major}.#{minor + 1}.0"
    when 'insignificant'
      "#{major}.#{minor}.#{patch + 1}"
    else
      model.semantic_version
    end
  end
end
