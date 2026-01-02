class EmploymentTenureUpdateForm < Reform::Form
  # Define form properties - Reform handles Rails integration automatically
  property :manager_teammate_id
  property :position_id
  property :employment_type
  property :seat_id
  property :termination_date, virtual: true  # Form-only field, not on the model
  property :reason, virtual: true  # Form-only field, not on the model

  # Use ActiveModel validations
  validates :position_id, presence: true
  validate :position_exists
  validate :manager_teammate_exists, if: -> { manager_teammate_id.present? }
  validate :seat_matches_position_type, if: -> { seat_id.present? }
  validate :termination_date_format, if: -> { termination_date.present? }
  validate :employment_type_inclusion, if: -> { employment_type.present? }
  validate :reason_only_with_major_changes

  # Override validate to store original params
  def validate(params)
    # Store original params BEFORE calling super (Reform may filter/modify params)
    # Handle ActionController::Parameters by converting to hash
    params_hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : (params.respond_to?(:to_h) ? params.to_h : params)
    @original_params = params_hash.dup
    # Convert to hash with string keys for consistency
    @original_params = @original_params.stringify_keys if @original_params.respond_to?(:stringify_keys)
    # Ensure we have a plain hash
    @original_params = @original_params.to_h if @original_params.respond_to?(:to_h) && !@original_params.is_a?(Hash)
    
    # Debug: Log termination_date before Reform processes it
    if @original_params['termination_date'].present?
      Rails.logger.debug "DEBUG EmploymentTenureUpdateForm: termination_date BEFORE super: #{@original_params['termination_date'].inspect}, class: #{@original_params['termination_date'].class}"
    end
    
    result = super
    
    # Debug: Log termination_date after Reform processes it
    if respond_to?(:termination_date) && termination_date.present?
      Rails.logger.debug "DEBUG EmploymentTenureUpdateForm: termination_date AFTER super: #{termination_date.inspect}, class: #{termination_date.class}"
    end
    
    result
  end

  # Reform automatically handles save - we customize the logic
  def save
    return false unless valid?
    
    # Call the service instead of saving the model directly
    # Build service params from @original_params (what was actually submitted)
    # The service needs all submitted params to detect changes correctly
    service_params = {}
    
    # Use @original_params as primary source (what was actually submitted)
    # This is critical - the service needs to know what was actually submitted to detect changes
    if @original_params && @original_params.any?
      @original_params.each do |key, value|
        key_sym = key.to_sym
        # Convert ID values to integers if they're strings
        if [:manager_teammate_id, :position_id, :seat_id].include?(key_sym)
          if value.is_a?(String) && value.present?
            service_params[key_sym] = value.to_i
          elsif value.nil? || value == ''
            service_params[key_sym] = nil
          else
            service_params[key_sym] = value
          end
        elsif key_sym == :termination_date
          # Keep termination_date as string - don't convert it to integer
          # Ensure it's a proper date string format
          if value.present?
            service_params[key_sym] = value.to_s.strip
          else
            service_params[key_sym] = nil
          end
        else
          service_params[key_sym] = value
        end
      end
    end
    
    # Fallback to form properties if @original_params not available
    # But prefer @original_params since it contains what was actually submitted
    service_params[:manager_teammate_id] ||= manager_teammate_id if respond_to?(:manager_teammate_id)
    service_params[:position_id] ||= position_id if respond_to?(:position_id) && position_id.present?
    service_params[:employment_type] ||= employment_type if respond_to?(:employment_type) && employment_type.present?
    service_params[:seat_id] ||= seat_id if respond_to?(:seat_id)
    # For termination_date, always use @original_params value if available, otherwise use form property
    # But ensure it's a string, not converted to integer
    if @original_params && @original_params['termination_date'].present?
      service_params[:termination_date] = @original_params['termination_date'].to_s.strip
    elsif respond_to?(:termination_date) && termination_date.present?
      service_params[:termination_date] = termination_date.to_s.strip
    end
    service_params[:reason] ||= reason if respond_to?(:reason) && reason.present?
    
    # Ensure position_id is always present (required field)
    service_params[:position_id] ||= position_id if respond_to?(:position_id)
    
    
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
    # Convert to integer if it's a string
    pos_id = position_id.is_a?(String) ? position_id.to_i : position_id
    
    # Check if position exists
    position = Position.find_by(id: pos_id)
    unless position
      errors.add(:position_id, 'does not exist')
      return
    end
    # Add validation check for position validity
    unless position.valid?
      errors.add(:position_id, 'is invalid - position level must be compatible with position type')
    end
  end

  def manager_teammate_exists
    return if manager_teammate_id.blank?
    unless CompanyTeammate.exists?(id: manager_teammate_id)
      errors.add(:manager_teammate_id, 'does not exist')
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
    manager_changed = manager_teammate_id.present? && model.manager_teammate_id.to_s != manager_teammate_id.to_s
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

