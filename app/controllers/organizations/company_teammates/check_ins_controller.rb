class Organizations::CompanyTeammates::CheckInsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  before_action :determine_view_mode

  def show
    # Initialize assigns before authorization to prevent nil errors on redirect
    @relevant_abilities = []
    
    authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy
    @person = @teammate.person
    
    # Create debug data if debug parameter is present
    if params[:debug] == 'true'
      debug_service = Debug::CheckInsDebugService.new(
        pundit_user: pundit_user,
        person: @teammate.person
      )
      @debug_data = debug_service.call
    end
    
    # Load or build all check-in types (spreadsheet-style)
    @position_check_in = load_or_build_position_check_in
    @assignment_check_ins = load_or_build_assignment_check_ins
    @aspiration_check_ins = load_or_build_aspiration_check_ins
    @relevant_abilities = load_relevant_abilities || []
  end
  
  def update
    # Parse giant form and update all check-ins
    # Handle both old and new parameter structures (with and without check_ins scope)
    check_ins_params = params[:check_ins] || params
    
    update_position_check_in(check_ins_params) if check_ins_params[:position_check_in] || check_ins_params["[position_check_in]"]
    update_assignment_check_ins(check_ins_params) if check_ins_params[:assignment_check_ins] || check_ins_params["[assignment_check_ins]"]
    update_aspiration_check_ins(check_ins_params) if check_ins_params[:aspiration_check_ins] || check_ins_params["[aspiration_check_ins]"]
    
    # Determine redirect URL based on button name
    redirect_url = determine_redirect_url
    
    redirect_to redirect_url, notice: 'Check-ins saved successfully.'
  end

  def save_and_redirect
    # This method is kept for backward compatibility but should not be used with new architecture
    # Parse giant form and update all check-ins
    # Handle both old and new parameter structures (with and without check_ins scope)
    check_ins_params = params[:check_ins] || params
    
    update_position_check_in(check_ins_params) if check_ins_params[:position_check_in] || check_ins_params["[position_check_in]"]
    update_assignment_check_ins(check_ins_params) if check_ins_params[:assignment_check_ins] || check_ins_params["[assignment_check_ins]"]
    update_aspiration_check_ins(check_ins_params) if check_ins_params[:aspiration_check_ins] || check_ins_params["[aspiration_check_ins]"]
    
    # Determine redirect URL based on button name
    redirect_url = determine_redirect_url
    
    redirect_to redirect_url, notice: 'Check-ins saved successfully.'
  end
  
  private
  
  def set_teammate
    @teammate = organization.teammates.find(params[:company_teammate_id])
  end
  
  def determine_view_mode
    Rails.logger.debug "=== VIEW MODE DETERMINATION ==="
    Rails.logger.debug "current_person: #{current_person&.display_name} (#{current_person&.id})"
    Rails.logger.debug "@teammate.person: #{@teammate.person&.display_name} (#{@teammate.person&.id})"
    Rails.logger.debug "current_person == @teammate.person: #{current_person == @teammate.person}"
    current_manager = @teammate.current_manager
    Rails.logger.debug "current_manager: #{current_manager&.display_name} (#{current_manager&.id})"
    Rails.logger.debug "current_manager == current_person: #{current_manager == current_person}"
    
    if current_person == @teammate.person
      @view_mode = :employee
      Rails.logger.debug "Setting view_mode to :employee"
    else
      # All non-employee viewers (including non-direct-managers) behave as managers
      @view_mode = :manager
      Rails.logger.debug "Setting view_mode to :manager"
    end
    Rails.logger.debug "Final view_mode: #{@view_mode}"
    Rails.logger.debug "=== END DEBUG ===\n"
  end

  def load_or_build_position_check_in
    check_in = PositionCheckIn.find_or_create_open_for(@teammate)
    check_in&.reload  # Ensure we have fresh data from the database
    check_in
  end

  def load_or_build_assignment_check_ins
    check_ins = []
    
    # Get all active assignment tenures for this teammate
    active_tenures = AssignmentTenure.joins(:assignment)
                                    .where(teammate: @teammate)
                                    .where(ended_at: nil)
                                    .includes(:assignment)
    
    # Find or create check-ins for each active assignment tenure
    active_tenures.each do |tenure|
      check_in = AssignmentCheckIn.find_or_create_open_for(@teammate, tenure.assignment)
      check_ins << check_in if check_in
    end
    
    # Get required and suggested assignments from the teammate's current position
    active_employment = @teammate.employment_tenures.active.where(company: organization).first
    if active_employment&.position
      position = active_employment.position
      required_assignments = position.required_assignments.map(&:assignment)
      suggested_assignments = position.suggested_assignments.map(&:assignment)
      position_assignments = required_assignments + suggested_assignments
      
      # For each position assignment (required or suggested), ensure we have a check-in
      position_assignments.each do |assignment|
        # Check if we already have a check-in for this assignment (from active tenure above)
        existing_check_in = check_ins.find { |ci| ci.assignment_id == assignment.id }
        next if existing_check_in
        
        # Check if there's an active tenure for this assignment
        active_tenure = active_tenures.find { |t| t.assignment_id == assignment.id }
        
        if active_tenure
          # Use existing method if tenure exists
          check_in = AssignmentCheckIn.find_or_create_open_for(@teammate, assignment)
          check_ins << check_in if check_in
        else
          # No active tenure - create blank check-in if one doesn't exist
          open_check_in = AssignmentCheckIn.where(teammate: @teammate, assignment: assignment).open.first
          if open_check_in.nil?
            check_in = AssignmentCheckIn.create!(
              teammate: @teammate,
              assignment: assignment,
              check_in_started_on: Date.current,
              actual_energy_percentage: nil
            )
            check_ins << check_in
          else
            check_ins << open_check_in
          end
        end
      end
    end
    
    check_ins = check_ins.compact
    
    # Separate check-ins into active tenure and non-active tenure groups
    active_tenure_check_ins = []
    non_active_tenure_check_ins = []
    
    check_ins.each do |check_in|
      tenure = check_in.assignment_tenure
      if tenure&.active?
        active_tenure_check_ins << check_in
      else
        non_active_tenure_check_ins << check_in
      end
    end
    
    # Sort active tenure check-ins by anticipated_energy_percentage (descending, largest first)
    # Place nil values at the end
    active_tenure_check_ins.sort_by! do |check_in|
      energy = check_in.assignment_tenure&.anticipated_energy_percentage
      # Use -1 * energy for descending order, but handle nil by using a very large number
      # so nil values sort to the end
      energy.nil? ? [1, 0] : [0, -energy]
    end
    
    # Combine: active tenure check-ins first, then others
    active_tenure_check_ins + non_active_tenure_check_ins
  end

  def load_or_build_aspiration_check_ins
    # Get all aspirations for this organization hierarchy
    aspirations = Aspiration.within_hierarchy(organization).ordered
    
    # For each aspiration, find or create an open check-in
    aspirations.map do |aspiration|
      AspirationCheckIn.find_or_create_open_for(@teammate, aspiration)
    end.compact
  end

  def load_relevant_abilities
    RelevantAbilitiesQuery.new(teammate: @teammate, organization: organization).call
  end

  def update_assignment_check_ins(check_ins_params = params)
    assignment_params = assignment_check_in_params(check_ins_params)
    return unless assignment_params.present?

    assignment_params.each do |check_in_id, attrs|
      assignment_id = attrs[:assignment_id]
      next unless assignment_id

      assignment = Assignment.find(assignment_id)
      
      # First, try to find an existing open check-in (it may have been created without a tenure)
      check_in = AssignmentCheckIn.where(teammate: @teammate, assignment: assignment).open.first
      
      # If no open check-in exists, try to find or create one (requires tenure)
      check_in ||= AssignmentCheckIn.find_or_create_open_for(@teammate, assignment)
      
      # If still no check-in and no tenure, create one anyway (matching load_or_build_assignment_check_ins behavior)
      if check_in.nil?
        check_in = AssignmentCheckIn.create!(
          teammate: @teammate,
          assignment: assignment,
          check_in_started_on: Date.current,
          actual_energy_percentage: nil
        )
      end
      
      next unless check_in

      # Handle status radio button
      if attrs[:status] == 'complete'
        # Only update fields that are present and not empty
        update_attrs = attrs.except(:status, :assignment_id).reject { |k, v| v.blank? }
        check_in.update!(update_attrs) if update_attrs.present?
        
        completion_service = CheckInCompletionService.new(check_in)
        
        if @view_mode == :employee
          completion_service.complete_employee_side!
        elsif @view_mode == :manager
          completion_service.complete_manager_side!(completed_by: current_company_teammate)
        end

        # Trigger notification if completion was detected
        if completion_service.completion_detected?
          CheckIns::NotifyCompletionJob.perform_and_get_result(
            check_in_id: check_in.id,
            check_in_type: 'AssignmentCheckIn',
            completion_state: completion_service.completion_state,
            organization_id: organization.id
          )
        end
      else
        # Save as draft - uncomplete if previously completed
        # Only update fields that are present and not empty
        update_attrs = attrs.except(:status, :assignment_id).reject { |k, v| v.blank? }
        check_in.update!(update_attrs) if update_attrs.present?
        
        if @view_mode == :employee
          check_in.uncomplete_employee_side!
        elsif @view_mode == :manager
          check_in.uncomplete_manager_side!
        end
      end
    end
  end

  def update_aspiration_check_ins(check_ins_params = params)
    aspiration_params = aspiration_check_in_params(check_ins_params)
    return unless aspiration_params.present?

    aspiration_params.each do |check_in_id, attrs|
      aspiration_id = attrs[:aspiration_id]
      next unless aspiration_id

      aspiration = Aspiration.find(aspiration_id)
      check_in = AspirationCheckIn.find_or_create_open_for(@teammate, aspiration)
      next unless check_in

      # Handle status radio button
      if attrs[:status] == 'complete'
        # Only update fields that are present and not empty
        update_attrs = attrs.except(:status, :aspiration_id).reject { |k, v| v.blank? }
        check_in.update!(update_attrs) if update_attrs.present?
        
        completion_service = CheckInCompletionService.new(check_in)
        
        if @view_mode == :employee
          completion_service.complete_employee_side!
        elsif @view_mode == :manager
          completion_service.complete_manager_side!(completed_by: current_company_teammate)
        end

        # Trigger notification if completion was detected
        if completion_service.completion_detected?
          CheckIns::NotifyCompletionJob.perform_and_get_result(
            check_in_id: check_in.id,
            check_in_type: 'AspirationCheckIn',
            completion_state: completion_service.completion_state,
            organization_id: organization.id
          )
        end
      else
        # Save as draft - uncomplete if previously completed
        # Only update fields that are present and not empty
        update_attrs = attrs.except(:status, :aspiration_id).reject { |k, v| v.blank? }
        check_in.update!(update_attrs) if update_attrs.present?
        
        if @view_mode == :employee
          check_in.uncomplete_employee_side!
        elsif @view_mode == :manager
          check_in.uncomplete_manager_side!
        end
      end
    end
  end
  
  def update_position_check_in(check_ins_params = params)
    check_in = PositionCheckIn.find_or_create_open_for(@teammate)
    # Handle both :position_check_in and "[position_check_in]" parameter formats
    attrs = position_check_in_params(check_ins_params)
    
    # Handle status radio button
    if attrs[:status] == 'complete'
      # Only update fields that are present and not empty
      update_attrs = attrs.except(:status).reject { |k, v| v.blank? }
      check_in.update!(update_attrs) if update_attrs.present?
      
      completion_service = CheckInCompletionService.new(check_in)
      
      if @view_mode == :employee
        completion_service.complete_employee_side!
      elsif @view_mode == :manager
        completion_service.complete_manager_side!(completed_by: current_company_teammate)
      end

      # Trigger notification if completion was detected
      if completion_service.completion_detected?
        CheckIns::NotifyCompletionJob.perform_and_get_result(
          check_in_id: check_in.id,
          check_in_type: 'PositionCheckIn',
          completion_state: completion_service.completion_state,
          organization_id: organization.id
        )
      end
    else
      # Save as draft - uncomplete if previously completed
      # Only update fields that are present and not empty
      update_attrs = attrs.except(:status).reject { |k, v| v.blank? }
      check_in.update!(update_attrs) if update_attrs.present?
      
      if @view_mode == :employee
        check_in.uncomplete_employee_side!
      elsif @view_mode == :manager
        check_in.uncomplete_manager_side!
      end
    end
  end

  def position_check_in_params(check_ins_params = params)
    # Handle position_check_in parameter format (both :position_check_in and "[position_check_in]")
    check_ins_params = check_ins_params[:check_ins] || check_ins_params
    position_params = check_ins_params[:position_check_in] || check_ins_params["[position_check_in]"]
    return {} unless position_params
    
    if @view_mode == :employee
      position_params.permit(:employee_rating, :employee_private_notes, :status)
    elsif @view_mode == :manager
      position_params.permit(:manager_rating, :manager_private_notes, :status)
    else
      {}
    end
  end
  
  def assignment_check_in_params(check_ins_params = params)
    # Handle assignment_check_ins parameter format (both :assignment_check_ins and "[assignment_check_ins]")
    assignment_params = check_ins_params[:assignment_check_ins] || check_ins_params["[assignment_check_ins]"] || {}
    
    permitted_params = {}
    assignment_params.each do |check_in_id, attrs|
      if @view_mode == :employee
        permitted_params[check_in_id] = attrs.permit(:assignment_id, :employee_rating, :actual_energy_percentage, :employee_personal_alignment, :employee_private_notes, :status)
      elsif @view_mode == :manager
        permitted_params[check_in_id] = attrs.permit(:assignment_id, :manager_rating, :manager_private_notes, :status)
      end
    end
    
    permitted_params
  end
  
  def aspiration_check_in_params(check_ins_params = params)
    # Handle aspiration_check_ins parameter format (both :aspiration_check_ins and "[aspiration_check_ins]")
    aspiration_params = check_ins_params[:aspiration_check_ins] || check_ins_params["[aspiration_check_ins]"] || {}
    
    permitted_params = {}
    aspiration_params.each do |check_in_id, attrs|
      if @view_mode == :employee
        permitted_params[check_in_id] = attrs.permit(:aspiration_id, :employee_rating, :employee_private_notes, :status)
      elsif @view_mode == :manager
        permitted_params[check_in_id] = attrs.permit(:aspiration_id, :manager_rating, :manager_private_notes, :status)
      end
    end
    
    permitted_params
  end

  def determine_redirect_url
    # Check for button names in params (new architecture)
    # Button names follow pattern: save_and_<action>_<type>_<id>
    button_name = find_button_name_in_params
    
    if button_name
      # Extract parameters needed for the service
      service_params = extract_service_params_for_button(button_name)
      
      CheckIns::RedirectUrlService.call(
        button_name: button_name,
        organization: organization,
        teammate: @teammate,
        params: service_params
      )
    elsif params[:redirect_to].present?
      # Handle old redirect_to parameter (from button_tag with name="redirect_to")
      params[:redirect_to]
    elsif params[:redirect_url].present?
      # Handle old redirect_url parameter (backward compatibility)
      params[:redirect_url]
    else
      # Default to finalization page
      organization_company_teammate_finalization_path(organization, @teammate)
    end
  end

  def find_button_name_in_params
    # Look for button names that start with "save_and_"
    params.each_key do |key|
      if key.to_s.start_with?('save_and_')
        return key.to_s
      end
    end
    nil
  end

  def extract_service_params_for_button(button_name)
    service_params = {}
    
    # Extract return_text and return_url if present
    service_params[:return_text] = params[:return_text] if params[:return_text].present?
    service_params[:return_url] = params[:return_url] if params[:return_url].present?
    
    # Extract since_date if present (can be a date string or Date object)
    if params[:since_date].present?
      service_params[:since_date] = params[:since_date]
    end
    
    # Extract teammate if present (for observations)
    if params[:teammate_id].present?
      service_params[:teammate] = organization.teammates.find_by(id: params[:teammate_id])
    end
    
    service_params
  end
  
end

