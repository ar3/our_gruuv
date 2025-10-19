class Organizations::CheckInsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_person
  before_action :set_teammate
  before_action :determine_view_mode

  def show
    authorize @person, :view_check_ins?
    
    # Determine view mode (card or table)
    @view_mode_param = params[:view] || 'table'  # Default to table view
    @view_mode_param = 'table' unless %w[card table].include?(@view_mode_param)
    
    # Load or build all check-in types (spreadsheet-style)
    @position_check_in = load_or_build_position_check_in
    @assignment_check_ins = load_or_build_assignment_check_ins
    @aspiration_check_ins = load_or_build_aspiration_check_ins
  end
  
  def update
    # Parse giant form and update all check-ins
    update_position_check_in if params[:position_check_in]
    update_assignment_check_ins if params[:assignment_check_ins]
    update_aspiration_check_ins if params[:aspiration_check_ins]
    
    redirect_to organization_person_check_ins_path(@organization, @person),
                notice: 'Check-ins saved successfully.'
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
    if current_person == @person
      @view_mode = :employee
    elsif @person.current_manager_for(@organization) == current_person
      @view_mode = :manager
    else
      @view_mode = :readonly
    end
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

  def update_assignment_check_ins
    assignment_check_ins_params = params[:assignment_check_ins] || params["[assignment_check_ins]"]
    return unless assignment_check_ins_params

    assignment_check_ins_params.each do |check_in_id, check_in_params|
      assignment_id = check_in_params[:assignment_id]
      next unless assignment_id

      assignment = Assignment.find(assignment_id)
      check_in = AssignmentCheckIn.find_or_create_open_for(@teammate, assignment)
      next unless check_in

      # Update check-in fields based on view mode
      if @view_mode == :employee
        check_in.assign_attributes(
          employee_rating: check_in_params[:employee_rating],
          employee_private_notes: check_in_params[:employee_private_notes],
          actual_energy_percentage: check_in_params[:actual_energy_percentage],
          employee_personal_alignment: check_in_params[:employee_personal_alignment]
        )
      elsif @view_mode == :manager
        check_in.assign_attributes(
          manager_rating: check_in_params[:manager_rating],
          manager_private_notes: check_in_params[:manager_private_notes]
        )
      end

      # Handle completion status
      if check_in_params[:status] == 'complete'
        if @view_mode == :employee
          check_in.complete_employee_side!
        elsif @view_mode == :manager
          check_in.complete_manager_side!(completed_by: current_person)
        end
      elsif check_in_params[:status] == 'draft'
        if @view_mode == :employee
          check_in.uncomplete_employee_side!
        elsif @view_mode == :manager
          check_in.uncomplete_manager_side!
        end
      end

      check_in.save!
    end
  end

  def update_aspiration_check_ins
    aspiration_check_ins_params = params[:aspiration_check_ins]
    return unless aspiration_check_ins_params

    aspiration_check_ins_params.each do |check_in_id, check_in_params|
      aspiration_id = check_in_params[:aspiration_id]
      next unless aspiration_id

      aspiration = Aspiration.find(aspiration_id)
      check_in = AspirationCheckIn.find_or_create_open_for(@teammate, aspiration)
      next unless check_in

      # Update check-in fields based on view mode
      if @view_mode == :employee
        check_in.assign_attributes(
          employee_rating: check_in_params[:employee_rating],
          employee_private_notes: check_in_params[:employee_private_notes]
        )
      elsif @view_mode == :manager
        check_in.assign_attributes(
          manager_rating: check_in_params[:manager_rating],
          manager_private_notes: check_in_params[:manager_private_notes]
        )
      end

      # Handle completion status
      if check_in_params[:status] == 'complete'
        if @view_mode == :employee
          check_in.complete_employee_side!
        elsif @view_mode == :manager
          check_in.complete_manager_side!(completed_by: current_person)
        end
      elsif check_in_params[:status] == 'draft'
        if @view_mode == :employee
          check_in.uncomplete_employee_side!
        elsif @view_mode == :manager
          check_in.uncomplete_manager_side!
        end
      end

      check_in.save!
    end
  end
  
  def update_position_check_in
    check_in = PositionCheckIn.find_or_create_open_for(@teammate)
    attrs = position_check_in_params
    
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

  def position_check_in_params
    # Handle position_check_in parameter format (both with and without brackets)
    position_params = params[:position_check_in] || params["[position_check_in]"]
    
    if @view_mode == :employee
      position_params.permit(:employee_rating, :employee_private_notes, :status)
    elsif @view_mode == :manager
      position_params.permit(:manager_rating, :manager_private_notes, :status)
    else
      {}
    end
  end
end