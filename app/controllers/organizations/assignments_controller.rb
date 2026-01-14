class Organizations::AssignmentsController < ApplicationController
  before_action :authenticate_person!
  before_action :set_organization
  before_action :set_assignment, only: [:show, :edit, :update, :destroy]

  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    company = @organization.root_company || @organization
    authorize company, :view_assignments?
    
    # Use query object for filtering and sorting
    query = AssignmentsQuery.new(
      @organization,
      params,
      current_person: current_person,
      policy_scope: policy_scope(Assignment)
    )
    
    @assignments = query.call
    
    # Set current filters, sort, view, and spotlight for view
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @current_spotlight = query.current_spotlight
    
    # Calculate spotlight stats for by_department (after filters, before sorting)
    if @current_spotlight == 'by_department'
      # Use filtered assignments for spotlight stats (load into array to preserve filters)
      filtered_assignments_array = @assignments.to_a
      @spotlight_stats = calculate_by_department_stats(filtered_assignments_array)
    end
    
    render layout: determine_layout
  end

  def show
    authorize @assignment
    
    # Load current holders (teammates with active assignment tenures)
    active_tenures = @assignment.assignment_tenures.active.includes(teammate: :person)
    @current_holders = active_tenures.map(&:teammate).uniq
    
    # Sort by last name, preferred name, first name
    @current_holders.sort_by! do |teammate|
      person = teammate.person
      [
        person.last_name.to_s.downcase,
        person.preferred_name.to_s.downcase,
        person.first_name.to_s.downcase
      ]
    end
    
    # Build a hash mapping teammate_id to their active tenure's anticipated_energy_percentage
    @holder_energy_percentages = {}
    active_tenures.each do |tenure|
      @holder_energy_percentages[tenure.teammate_id] = tenure.anticipated_energy_percentage
    end
    
    # Analytics data
    # Number of teammates who have ever had a tenure of this assignment
    @teammates_with_tenure_count = @assignment.assignment_tenures
      .select(:teammate_id)
      .distinct
      .count
    
    # Number of total finalized check-ins of this assignment
    @finalized_check_ins_count = AssignmentCheckIn
      .joins(:teammate)
      .where(assignment: @assignment)
      .closed
      .count
    
    # Number of active assignment_tenures
    @active_tenures_count = @assignment.assignment_tenures.active.count
    
    # Anticipated_energy_percentage based on all active assignment_tenures
    active_tenures = @assignment.assignment_tenures.active
    if active_tenures.any?
      energy_values = active_tenures.where.not(anticipated_energy_percentage: nil).pluck(:anticipated_energy_percentage)
      @average_energy_percentage = energy_values.any? ? (energy_values.sum.to_f / energy_values.count).round(1) : nil
    else
      @average_energy_percentage = nil
    end
    
    # Number of teammates with finalized check-ins
    @teammates_with_finalized_check_ins_count = AssignmentCheckIn
      .joins(:teammate)
      .where(assignment: @assignment)
      .closed
      .select(:teammate_id)
      .distinct
      .count
    
    # Most popular official_rating (if >5 teammates with finalized check-ins)
    if @teammates_with_finalized_check_ins_count > 5
      finalized_check_ins = AssignmentCheckIn
        .joins(:teammate)
        .where(assignment: @assignment)
        .closed
        .where.not(official_rating: nil)
      
      rating_counts = finalized_check_ins.group(:official_rating).count
      @most_popular_official_rating = rating_counts.max_by { |_k, v| v }&.first
    else
      @most_popular_official_rating = nil
    end
    
    # Most popular employee_personal_alignment (if >5 teammates with finalized check-ins)
    if @teammates_with_finalized_check_ins_count > 5
      finalized_check_ins = AssignmentCheckIn
        .joins(:teammate)
        .where(assignment: @assignment)
        .closed
        .where.not(employee_personal_alignment: nil)
      
      alignment_counts = finalized_check_ins.group(:employee_personal_alignment).count
      @most_popular_personal_alignment = alignment_counts.max_by { |_k, v| v }&.first
    else
      @most_popular_personal_alignment = nil
    end
    
    # Load consumer assignments (assignments that benefit from this assignment)
    @consumer_assignments = @assignment.consumer_assignments.includes(:department, :company).order(:title)
    
    # Load positions that require or suggest this assignment
    @position_assignments = @assignment.position_assignments
      .includes(position: [:position_type, :position_level])
      .joins(position: [:position_type, :position_level])
      .order('position_assignments.assignment_type, position_types.external_title, position_levels.level')
    
    render layout: determine_layout
  end

  def new
    @assignment = @organization.assignments.build
    @assignment_decorator = AssignmentDecorator.new(@assignment)
    @form = AssignmentForm.new(@assignment)
    @form.current_person = current_person
    @form.instance_variable_set(:@form_data_empty, true)
    authorize @assignment
    render layout: determine_layout
  end

  def create
    @assignment = @organization.assignments.build
    @assignment_decorator = AssignmentDecorator.new(@assignment)
    @form = AssignmentForm.new(@assignment)
    @form.current_person = current_person
    
    authorize @assignment
    
    # Set flag for empty form data validation
    assignment_params_hash = assignment_params || {}
    @form.instance_variable_set(:@form_data_empty, assignment_params_hash.empty?)

    if @form.validate(assignment_params) && @form.save
      # Create external references if URLs provided
      create_external_references(@assignment, params[:assignment])
      
      # Create outcomes from textarea if provided
      if params[:assignment][:outcomes_textarea].present?
        @assignment.create_outcomes_from_textarea(params[:assignment][:outcomes_textarea])
      end
      
      redirect_to organization_assignment_path(@organization, @assignment), notice: 'Assignment was successfully created.'
    else
      # Preserve outcomes_textarea for re-render
      @form.outcomes_textarea = params[:assignment][:outcomes_textarea] if params[:assignment][:outcomes_textarea].present?
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @assignment_decorator = AssignmentDecorator.new(@assignment)
    @form = AssignmentForm.new(@assignment)
    @form.current_person = current_person
    authorize @assignment
    render layout: determine_layout
  end

  def update
    @assignment_decorator = AssignmentDecorator.new(@assignment)
    @form = AssignmentForm.new(@assignment)
    @form.current_person = current_person
    
    authorize @assignment
    
    # Set flag for empty form data validation
    assignment_params_hash = assignment_params || {}
    @form.instance_variable_set(:@form_data_empty, assignment_params_hash.empty?)

    if @form.validate(assignment_params) && @form.save
      update_external_references(@assignment, params[:assignment])
      
      # Handle existing outcomes updates and deletions
      handle_existing_outcomes(params)
      
      # Handle new outcomes from textarea
      if params[:assignment][:outcomes_textarea].present?
        @assignment.create_outcomes_from_textarea(params[:assignment][:outcomes_textarea])
      end
      
      redirect_to organization_assignment_path(@organization, @assignment), notice: 'Assignment was successfully updated.'
    else
      # Preserve outcomes_textarea for re-render
      @form.outcomes_textarea = params[:assignment][:outcomes_textarea] if params[:assignment][:outcomes_textarea].present?
      
      flash[:alert] = @form.errors.full_messages.join(', ') if @form.errors.any?
      
      error_message = @form.errors.full_messages.any? ? @form.errors.full_messages.join(', ') : 'Unknown validation error'
      flash[:alert] = "Failed to update assignment: #{error_message}"
      redirect_to edit_organization_assignment_path(@organization, @assignment)
    end
  end

  def destroy
    authorize @assignment
    @assignment.destroy
    redirect_to organization_assignments_path(@organization), notice: 'Assignment was successfully deleted.'
  end

  def customize_view
    authorize @organization, :show?
    
    # Use query object to get current state
    query = AssignmentsQuery.new(@organization, params, current_person: current_person)
    @current_filters = query.current_filters
    @current_sort = query.current_sort
    @current_view = query.current_view
    @current_spotlight = query.current_spotlight
    
    # Preserve current params for return URL
    return_params = params.except(:controller, :action, :page).permit!.to_h
    @return_url = organization_assignments_path(@organization, return_params)
    @return_text = "Back to Assignments"
    
    render layout: 'overlay'
  end

  def update_view
    authorize @organization, :show?
    
    # Build redirect URL with all view customization params
    # Handle departments as comma-separated list
    redirect_params = {}
    if params[:departments].present?
      # Convert array to comma-separated string if needed
      departments_value = if params[:departments].is_a?(Array)
        params[:departments].reject(&:blank?).join(',')
      else
        params[:departments].to_s
      end
      redirect_params[:departments] = departments_value if departments_value.present?
    end
    redirect_params[:outcomes_filter] = params[:outcomes_filter] if params[:outcomes_filter].present?
    redirect_params[:abilities_filter] = params[:abilities_filter] if params[:abilities_filter].present?
    redirect_params[:major_version] = params[:major_version] if params[:major_version].present?
    redirect_params[:sort] = params[:sort] if params[:sort].present?
    redirect_params[:direction] = params[:direction] if params[:direction].present?
    redirect_params[:view] = params[:view] if params[:view].present?
    redirect_params[:spotlight] = params[:spotlight] if params[:spotlight].present?
    
    redirect_to organization_assignments_path(@organization, redirect_params)
  end

  private

  def set_organization
    @organization = Organization.find(params[:organization_id])
  end

  def set_assignment
    @assignment = @organization.assignments.find(params[:id])
  end

  def calculate_by_department_stats(assignments)
    # Group assignments by their department (or "No Department" if nil)
    assignments_by_dept = assignments.group_by(&:department)
    
    # Build stats hash with department display names and counts
    stats = {}
    assignments_by_dept.each do |dept, dept_assignments|
      if dept.nil?
        stats[nil] = {
          department: nil,
          display_name: 'No Department',
          count: dept_assignments.count
        }
      else
        stats[dept.id] = {
          department: dept,
          display_name: dept.display_name,
          count: dept_assignments.count
        }
      end
    end
    
    {
      departments: stats,
      total_assignments: assignments.count,
      total_departments: stats.count
    }
  end

  def assignment_params
    params.require(:assignment).permit(:title, :tagline, :required_activities, :handbook, :department_id, :version_type, :outcomes_textarea, :published_source_url, :draft_source_url)
  end

  def create_external_references(assignment, params)
    if params[:published_source_url].present?
      assignment.create_published_external_reference!(
        url: params[:published_source_url],
        reference_type: 'published'
      )
    end
    
    if params[:draft_source_url].present?
      assignment.create_draft_external_reference!(
        url: params[:draft_source_url],
        reference_type: 'draft'
      )
    end
  end

  def update_external_references(assignment, params)
    # Update or create published reference
    if params[:published_source_url].present?
      if assignment.published_external_reference
        assignment.published_external_reference.update!(url: params[:published_source_url])
      else
        assignment.create_published_external_reference!(url: params[:published_source_url], reference_type: 'published')
      end
    elsif assignment.published_external_reference
      assignment.published_external_reference.destroy
    end
    
    # Update or create draft reference
    if params[:draft_source_url].present?
      if assignment.draft_external_reference
        assignment.draft_external_reference.update!(url: params[:draft_source_url])
      else
        assignment.create_draft_external_reference!(url: params[:draft_source_url], reference_type: 'draft')
      end
    elsif assignment.draft_external_reference
      assignment.draft_external_reference.destroy
    end
  end

  def handle_existing_outcomes(params)
    @assignment.assignment_outcomes.each do |outcome|
      outcome_id = outcome.id.to_s
      
      # Check if this outcome is marked for deletion
      if params[:assignment]["outcome_delete_#{outcome_id}"] == "1"
        outcome.destroy
      else
        # Update the outcome with new values
        description_param = params[:assignment]["outcome_description_#{outcome_id}"]
        type_param = params[:assignment]["outcome_type_#{outcome_id}"]
        
        if description_param.present? && type_param.present?
          outcome.update!(
            description: description_param.strip,
            outcome_type: type_param
          )
        end
      end
    end
  end
end
