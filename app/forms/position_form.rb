class PositionForm < Reform::Form
  include FormSemanticVersionable

  # Define form properties - Reform handles Rails integration automatically
  property :title_id
  property :position_level_id
  property :position_summary
  property :eligibility_requirements_summary
  property :version_type, virtual: true

  # Use ActiveModel validations
  validates :title_id, presence: true
  validates :position_level_id, presence: true
  validates :version_type, presence: true, unless: :new_form_without_data?
  validate :version_type_for_context
  validate :form_data_present

  # Reform automatically handles save - we just need to customize the logic
  def save
    return false unless valid?
    
    # Store version_type and model state before super (virtual property might be lost)
    stored_version_type = version_type
    was_new_record = model.new_record?
    
    # Let Reform sync the form data to the model first
    super
    
    # Set associations if IDs are present
    if title_id.present?
      model.title = Title.find(title_id)
    end
    if position_level_id.present?
      model.position_level = PositionLevel.find(position_level_id)
    end
    
    # Calculate semantic version using stored version_type
    if was_new_record
      model.semantic_version = calculate_version_for_new(stored_version_type)
    else
      model.semantic_version = calculate_version_for_existing(stored_version_type)
    end
    
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

  def calculate_semantic_version
    if model.persisted?
      calculate_version_for_existing
    else
      calculate_version_for_new
    end
  end

  def calculate_version_for_new(version_type_value = nil)
    version_type_value ||= version_type
    case version_type_value
    when 'ready'
      "1.0.0"
    when 'nearly_ready'
      "0.1.0"
    when 'early_draft'
      "0.0.1"
    else
      "0.0.1"
    end
  end

  def calculate_version_for_existing(version_type_value = nil)
    version_type_value ||= version_type
    return model.semantic_version unless model.semantic_version.present?

    major, minor, patch = model.semantic_version.split('.').map(&:to_i)

    case version_type_value
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

  def new_form_without_data?
    model.new_record? && !@form_data_empty.nil? && @form_data_empty
  end

  def version_type_for_context
    return unless version_type.present?
    
    if model.persisted?
      unless %w[fundamental clarifying insignificant].include?(version_type)
        errors.add(:version_type, "must be fundamental, clarifying, or insignificant for existing position")
      end
    else
      unless %w[ready nearly_ready early_draft].include?(version_type)
        errors.add(:version_type, "must be ready, nearly ready, or early draft for new position")
      end
    end
  end

  private

  def form_data_present
    # Check if any form fields have been provided
    # This validation only runs when no position parameters are provided at all
    if @form_data_empty
      errors.add(:base, "Form data is missing. Please fill out the form and try again.")
    end
  end
end

