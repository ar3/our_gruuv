class Organizations::CheckInsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_person
  before_action :set_teammate
  before_action :determine_view_mode

  def show
    authorize @person, :view_check_ins?, policy_class: PersonPolicy
    
    # Determine view mode (card or table)
    @view_mode_param = params[:view] || 'table'  # Default to table view
    @view_mode_param = 'table' unless %w[card table].include?(@view_mode_param)
    
    # Load or build all check-in types (spreadsheet-style)
    @position_check_in = load_or_build_position_check_in
    @assignment_check_ins = load_or_build_assignment_check_ins
    @aspiration_check_ins = load_or_build_aspiration_check_ins
    @relevant_abilities = load_relevant_abilities
  end
  
  def update
    # Parse giant form and update all check-ins
    # Handle both old and new parameter structures (with and without check_ins scope)
    check_ins_params = params[:check_ins] || params
    
    update_position_check_in(check_ins_params) if check_ins_params[:position_check_in] || check_ins_params["[position_check_in]"]
    update_assignment_check_ins(check_ins_params) if check_ins_params[:assignment_check_ins] || check_ins_params["[assignment_check_ins]"]
    update_aspiration_check_ins(check_ins_params) if check_ins_params[:aspiration_check_ins] || check_ins_params["[aspiration_check_ins]"]
    
    # Redirect to specified URL if provided, otherwise redirect back to check-ins page
    redirect_url = params[:redirect_to].presence || organization_person_check_ins_path(@organization, @person)
    redirect_to redirect_url, notice: 'Check-ins saved successfully.'
  end
  
  private
  
  def set_organization
    @organization = Organization.find(params[:organization_id])
  end
  
  def set_person
    @person = Person.find(params[:person_id])
  end
  
  def set_teammate
    # Find teammate within the organization hierarchy
    # This handles cases where a person has a teammate record at a child department
    # but we're viewing check-ins at the company level
    @teammate = @person.teammates.for_organization_hierarchy(@organization).first
  end
  
  def determine_view_mode
    Rails.logger.debug "=== VIEW MODE DETERMINATION ==="
    Rails.logger.debug "current_person: #{current_person&.display_name} (#{current_person&.id})"
    Rails.logger.debug "@person: #{@person&.display_name} (#{@person&.id})"
    Rails.logger.debug "current_person == @person: #{current_person == @person}"
    Rails.logger.debug "current_manager: #{@person&.current_manager_for(@organization)&.display_name} (#{@person&.current_manager_for(@organization)&.id})"
    Rails.logger.debug "current_manager == current_person: #{@person&.current_manager_for(@organization) == current_person}"
    
    if current_person == @person
      @view_mode = :employee
      Rails.logger.debug "Setting view_mode to :employee"
    elsif @person.current_manager_for(@organization) == current_person
      @view_mode = :manager
      Rails.logger.debug "Setting view_mode to :manager"
    else
      @view_mode = :readonly
      Rails.logger.debug "Setting view_mode to :readonly"
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
    # Get all active assignment tenures for this teammate
    active_tenures = AssignmentTenure.joins(:assignment)
                                    .where(teammate: @teammate)
                                    .where(ended_at: nil)
                                    .includes(:assignment)
    
    # Find or create check-ins for each active assignment
    active_tenures.map do |tenure|
      AssignmentCheckIn.find_or_create_open_for(@teammate, tenure.assignment)
    end.compact
  end

  def load_or_build_aspiration_check_ins
    # Get all aspirations for this organization hierarchy
    aspirations = Aspiration.within_hierarchy(@organization).ordered
    
    # For each aspiration, find or create an open check-in
    aspirations.map do |aspiration|
      AspirationCheckIn.find_or_create_open_for(@teammate, aspiration)
    end.compact
  end

  def load_relevant_abilities
    RelevantAbilitiesQuery.new(teammate: @teammate, organization: @organization).call
  end

  def update_assignment_check_ins(check_ins_params = params)
    assignment_params = assignment_check_in_params(check_ins_params)
    return unless assignment_params.present?

    assignment_params.each do |check_in_id, attrs|
      assignment_id = attrs[:assignment_id]
      next unless assignment_id

      assignment = Assignment.find(assignment_id)
      check_in = AssignmentCheckIn.find_or_create_open_for(@teammate, assignment)
      next unless check_in

      # Handle status radio button
      if attrs[:status] == 'complete'
        # Only update fields that are present and not empty
        update_attrs = attrs.except(:status, :assignment_id).reject { |k, v| v.blank? }
        check_in.update!(update_attrs) if update_attrs.present?
        
        if @view_mode == :employee
          check_in.complete_employee_side!
        elsif @view_mode == :manager
          check_in.complete_manager_side!(completed_by: current_person)
        elsif @view_mode == :readonly
          # For readonly, determine which side to complete based on what fields are present
          if attrs[:employee_rating].present? || attrs[:employee_private_notes].present?
            check_in.complete_employee_side!
          end
          if attrs[:manager_rating].present? || attrs[:manager_private_notes].present?
            check_in.complete_manager_side!(completed_by: current_person)
          end
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
        elsif @view_mode == :readonly
          # For readonly, uncomplete both sides
          check_in.uncomplete_employee_side!
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
        
        if @view_mode == :employee
          check_in.complete_employee_side!
        elsif @view_mode == :manager
          check_in.complete_manager_side!(completed_by: current_person)
        elsif @view_mode == :readonly
          # For readonly, determine which side to complete based on what fields are present
          if attrs[:employee_rating].present? || attrs[:employee_private_notes].present?
            check_in.complete_employee_side!
          end
          if attrs[:manager_rating].present? || attrs[:manager_private_notes].present?
            check_in.complete_manager_side!(completed_by: current_person)
          end
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
        elsif @view_mode == :readonly
          # For readonly, uncomplete both sides
          check_in.uncomplete_employee_side!
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
      
      if @view_mode == :employee
        check_in.complete_employee_side!
      elsif @view_mode == :manager
        check_in.complete_manager_side!(completed_by: current_person)
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
      elsif @view_mode == :readonly
        # For readonly, permit all fields
        permitted_params[check_in_id] = attrs.permit(:assignment_id, :employee_rating, :actual_energy_percentage, :employee_personal_alignment, :employee_private_notes, :manager_rating, :manager_private_notes, :status)
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
      elsif @view_mode == :readonly
        # For readonly, permit all fields
        permitted_params[check_in_id] = attrs.permit(:aspiration_id, :employee_rating, :employee_private_notes, :manager_rating, :manager_private_notes, :status)
      end
    end
    
    permitted_params
  end
end