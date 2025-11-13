class EmploymentTenureUpdateForm < Reform::Form
  # Define form properties - Reform handles Rails integration automatically
  property :manager_id
  property :position_id
  property :employment_type
  property :seat_id
  property :termination_date, virtual: true  # Form-only field, not on the model
  property :reason, virtual: true  # Form-only field, not on the model

  # Use ActiveModel validations
  validates :position_id, presence: true
  validate :position_exists
  validate :manager_exists, if: -> { manager_id.present? }
  validate :seat_matches_position_type, if: -> { seat_id.present? }
  validate :termination_date_format, if: -> { termination_date.present? }
  validate :employment_type_inclusion, if: -> { employment_type.present? }
  validate :reason_only_with_major_changes

  # Override validate to store original params
  def validate(params)
    # Store original params with both string and symbol keys for compatibility
    @original_params = params.dup
    # Convert to hash with indifferent access
    @original_params = @original_params.with_indifferent_access if @original_params.respond_to?(:with_indifferent_access)
    super
  end

  # Reform automatically handles save - we customize the logic
  def save
    return false unless valid?
    
    # Call the service instead of saving the model directly
    # Use original params so service can detect what was actually provided vs what came from model
    # Convert to symbol keys for service
    service_params = {}
    @original_params.each do |key, value|
      service_params[key.to_sym] = value
    end
    
    # Ensure position_id is always present (required field)
    service_params[:position_id] ||= position_id
    
    result = UpdateEmploymentTenureService.call(
      teammate: teammate,
      current_tenure: model,
      params: service_params,
      created_by: current_person
    )
    
    if result.ok?
      true
    else
      errors.add(:base, result.error)
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

  # Helper method to get teammate (passed from controller)
  def teammate
    @teammate
  end

  # Helper method to set teammate
  def teammate=(teammate)
    @teammate = teammate
  end

  private

  def position_exists
    return if position_id.blank?
    unless Position.exists?(id: position_id)
      errors.add(:position_id, 'does not exist')
    end
  end

  def manager_exists
    return if manager_id.blank?
    unless Person.exists?(id: manager_id)
      errors.add(:manager_id, 'does not exist')
    end
  end

  def seat_matches_position_type
    return if seat_id.blank? || position_id.blank?
    
    seat = Seat.find_by(id: seat_id)
    position = Position.find_by(id: position_id)
    
    return unless seat && position
    
    unless seat.position_type_id == position.position_type_id
      errors.add(:seat, 'must match the position type of the selected position')
    end
  end

  def termination_date_format
    return if termination_date.blank?
    
    # Try to parse as date
    begin
      Date.parse(termination_date.to_s)
    rescue ArgumentError
      errors.add(:termination_date, 'must be a valid date')
    end
  end

  def employment_type_inclusion
    return if employment_type.blank?
    
    valid_types = %w[full_time part_time contract contractor intern temporary consultant freelance]
    unless valid_types.include?(employment_type)
      errors.add(:employment_type, 'is not included in the list')
    end
  end

  def reason_only_with_major_changes
    return if reason.blank?
    
    # Check if any major changes are present
    manager_changed = manager_id.present? && model.manager_id.to_s != manager_id.to_s
    position_changed = position_id.present? && model.position_id.to_s != position_id.to_s
    employment_type_changed = employment_type.present? && model.employment_type.to_s != employment_type.to_s
    termination_date_provided = termination_date.present?
    seat_changed = seat_id.present? && model.seat_id.to_s != seat_id.to_s
    
    major_changes = manager_changed || position_changed || employment_type_changed || termination_date_provided
    any_changes = major_changes || seat_changed
    
    # Only error if reason is provided with NO changes at all
    # If there are changes (even non-major like seat), form is valid but reason won't be saved
    unless any_changes
      errors.add(:reason, 'The reason field is only saved when a major change is made (manager, position, employment type, or termination date)')
    end
  end
end

