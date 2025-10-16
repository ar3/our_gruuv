class Organizations::CheckInsController < ApplicationController
  before_action :authenticate_person!
  before_action :set_organization
  before_action :set_person
  before_action :set_teammate
  before_action :determine_view_mode

  def show
    authorize @person, :view_check_ins?
    
    puts "DEBUG: Loading check-ins for #{@person.display_name}"
    
    # Load or build all check-in types (spreadsheet-style)
    @position_check_in = load_or_build_position_check_in
    @assignment_check_ins = load_or_build_assignment_check_ins
    @aspiration_check_ins = load_or_build_aspiration_check_ins
    
    puts "DEBUG: Loaded #{@assignment_check_ins.count} assignment check-ins"
  end
  
  def update
    # Parse giant form and update all check-ins
    update_position_check_in if params[:position_check_in] || params['[position_check_in]']
    update_assignment_check_ins if params[:assignment_check_ins] || params['[assignment_check_ins]']
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
    @teammate = @person.teammates.find_by(organization: @organization)
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
    PositionCheckIn.find_or_create_open_for(@teammate)
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
    # Implemented in Phase 3
    []
  end

  def update_assignment_check_ins
    assignment_check_ins_params = params[:assignment_check_ins] || params['[assignment_check_ins]']
    return unless assignment_check_ins_params

    assignment_check_ins_params.each do |check_in_id, check_in_params|
      assignment_id = check_in_params[:assignment_id]
      next unless assignment_id

      assignment = Assignment.find(assignment_id)
      check_in = AssignmentCheckIn.find_or_create_open_for(@teammate, assignment)
      next unless check_in

      # Update check-in fields
      check_in.assign_attributes(
        employee_rating: check_in_params[:employee_rating],
        manager_rating: check_in_params[:manager_rating],
        employee_private_notes: check_in_params[:employee_private_notes],
        manager_private_notes: check_in_params[:manager_private_notes],
        actual_energy_percentage: check_in_params[:actual_energy_percentage],
        employee_personal_alignment: check_in_params[:employee_personal_alignment]
      )

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
    # Implemented in Phase 3
  end
  
  def update_position_check_in
    check_in = PositionCheckIn.find_or_create_open_for(@teammate)
    attrs = position_check_in_params
    
    # Handle status radio button
    if attrs[:status] == 'complete'
      check_in.update!(attrs.except(:status))
      if @view_mode == :employee
        check_in.complete_employee_side!
      elsif @view_mode == :manager
        check_in.complete_manager_side!(completed_by: current_person)
      end
    else
      # Save as draft - uncomplete if previously completed
      check_in.update!(attrs.except(:status))
      if @view_mode == :employee
        check_in.uncomplete_employee_side!
      elsif @view_mode == :manager
        check_in.uncomplete_manager_side!
      end
    end
  end

  def position_check_in_params
    # Handle both :position_check_in and '[position_check_in]' parameter formats
    position_params = params[:position_check_in] || params['[position_check_in]']
    
    if @view_mode == :employee
      position_params.permit(:employee_rating, :employee_private_notes, :status)
    elsif @view_mode == :manager
      position_params.permit(:manager_rating, :manager_private_notes, :status)
    else
      {}
    end
  end
end