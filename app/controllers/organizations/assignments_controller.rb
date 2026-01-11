class Organizations::AssignmentsController < ApplicationController
  before_action :authenticate_person!
  before_action :set_organization
  before_action :set_assignment, only: [:show, :edit, :update, :destroy]

  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    company = @organization.root_company || @organization
    authorize company, :view_assignments?
    
    # Set default spotlight
    @current_spotlight = params[:spotlight].presence || 'by_department'
    
    @assignments = policy_scope(Assignment).where(company: company.self_and_descendants).includes(
      :assignment_outcomes, 
      :published_external_reference, 
      :draft_external_reference, 
      :abilities,
      assignment_abilities: :ability,
      position_assignments: { position: [:position_type, :position_level] }
    )
    
    # Apply filters
    if params[:company].present?
      company_params = params[:company].is_a?(Array) ? params[:company] : [params[:company]]
      selected_company_ids = company_params.map(&:to_i).reject(&:zero?)
      if selected_company_ids.any?
        selected_companies = Organization.where(id: selected_company_ids)
        company_ids = selected_companies.flat_map { |c| c.self_and_descendants.pluck(:id) }.uniq
        @assignments = @assignments.where(company_id: company_ids)
      end
    end
    
    # Apply outcomes filter (tri-state: all, with, without)
    case params[:outcomes_filter]
    when 'with'
      @assignments = @assignments.joins(:assignment_outcomes).distinct
    when 'without'
      @assignments = @assignments.left_joins(:assignment_outcomes)
                                 .where(assignment_outcomes: { id: nil })
    # when 'all' or blank/nil - no filter applied
    end
    
    # Apply abilities filter (tri-state: all, with, without)
    case params[:abilities_filter]
    when 'with'
      @assignments = @assignments.joins(:abilities).distinct
    when 'without'
      @assignments = @assignments.left_joins(:abilities)
                                 .where(assignment_abilities: { id: nil })
    # when 'all' or blank/nil - no filter applied
    end
    
    # Filter by major version (using SQL LIKE for efficiency)
    if params[:major_version].present?
      major_version = params[:major_version].to_i
      @assignments = @assignments.where("semantic_version LIKE ?", "#{major_version}.%")
    end
    
    # Calculate spotlight stats for by_department (after filters, before sorting)
    if @current_spotlight == 'by_department'
      # Use filtered assignments for spotlight stats (load into array to preserve filters)
      filtered_assignments_array = @assignments.to_a
      @spotlight_stats = calculate_by_department_stats(filtered_assignments_array)
    end
    
    # Apply sorting - need to handle distinct queries properly
    # Check if we're using distinct (from joins)
    using_distinct = @assignments.to_sql.include?('DISTINCT')
    
    case params[:sort]
    when 'department_and_title'
      if using_distinct
        @assignments = @assignments.reorder('assignments.title')
      else
        @assignments = @assignments.left_joins(:department).order(Arel.sql('COALESCE(organizations.name, \'\')'), 'assignments.title')
      end
    when 'title'
      @assignments = @assignments.order('assignments.title')
    when 'title_desc'
      @assignments = @assignments.order('assignments.title DESC')
    when 'company'
      if using_distinct
        @assignments = @assignments.reorder('assignments.title')
      else
        @assignments = @assignments.joins(:company).order('organizations.display_name')
      end
    when 'company_desc'
      if using_distinct
        @assignments = @assignments.reorder('assignments.title DESC')
      else
        @assignments = @assignments.joins(:company).order('organizations.display_name DESC')
      end
    when 'outcomes'
      @assignments = @assignments.left_joins(:assignment_outcomes).group('assignments.id').order('COUNT(assignment_outcomes.id) DESC')
    when 'outcomes_desc'
      @assignments = @assignments.left_joins(:assignment_outcomes).group('assignments.id').order('COUNT(assignment_outcomes.id) ASC')
    when 'abilities'
      @assignments = @assignments.left_joins(:abilities).group('assignments.id').order('COUNT(assignment_abilities.id) DESC')
    when 'abilities_desc'
      @assignments = @assignments.left_joins(:abilities).group('assignments.id').order('COUNT(assignment_abilities.id) ASC')
    else
      if using_distinct
        @assignments = @assignments.reorder('assignments.title')
      else
        @assignments = @assignments.left_joins(:department).order(Arel.sql('COALESCE(organizations.name, \'\')'), 'assignments.title')
      end
    end
    
    render layout: determine_layout
  end

  def show
    authorize @assignment
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
    
    # Load current state from params
    @current_filters = {
      company: params[:company] || [],
      outcomes_filter: params[:outcomes_filter] || 'all',
      abilities_filter: params[:abilities_filter] || 'all',
      major_version: params[:major_version],
      sort: params[:sort] || 'department_and_title',
      direction: params[:direction] || 'asc',
      view: params[:view] || 'table',
      spotlight: params[:spotlight] || 'by_department'
    }
    
    @current_sort = @current_filters[:sort]
    @current_view = @current_filters[:view]
    @current_spotlight = @current_filters[:spotlight]
    
    # Preserve current params for return URL
    return_params = params.except(:controller, :action, :page).permit!.to_h
    @return_url = organization_assignments_path(@organization, return_params)
    @return_text = "Back to Assignments"
    
    render layout: 'overlay'
  end

  def update_view
    authorize @organization, :show?
    
    # Build redirect URL with all view customization params
    # Handle array params (company[]) properly
    redirect_params = {}
    redirect_params[:company] = params[:company] if params[:company].present?
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
