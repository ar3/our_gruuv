class AspirationForm < Reform::Form
  # Define form properties - Reform handles Rails integration automatically
  property :name
  property :description
  property :organization_id
  property :sort_order

  # Use ActiveModel validations for now - we can upgrade to dry-validation later
  validates :name, presence: true
  validates :sort_order, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :organization_id, presence: true
  validate :validate_uniqueness_of_name

  # Reform automatically handles save - we just need to customize the logic
  def save
    return false unless valid?
    
    # Let Reform sync the form data to the model first
    super
    
    # Set audit fields if they exist on the model
    if model.respond_to?(:created_by) && model.new_record?
      model.created_by = current_person
    end
    if model.respond_to?(:updated_by)
      model.updated_by = current_person
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

  # Helper method to get the organization for this form
  def organization
    return nil unless organization_id.present?
    @organization ||= Organization.find(organization_id)
  end

  # Helper method to set organization
  def organization=(org)
    self.organization_id = org.id
    @organization = org
  end

  private

  # Custom validation method for uniqueness
  def validate_uniqueness_of_name
    return unless name.present? && organization_id.present?
    
    existing_aspiration = Aspiration.where(
      name: name,
      organization_id: organization_id
    ).where.not(id: model.id).first
    
    if existing_aspiration
      errors.add(:name, 'has already been taken')
    end
  end
end
