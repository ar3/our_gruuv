class Organizations::AssignmentsController < ApplicationController
  before_action :authenticate_person!
  before_action :set_organization
  before_action :set_assignment, only: [:show, :edit, :update, :destroy]

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    @assignments = policy_scope(Assignment).where(company: @organization.root_company.self_and_descendants).includes(:assignment_outcomes, :published_external_reference, :draft_external_reference, :abilities)
    
    # Apply filters
    if params[:company].present?
      company = Organization.find(params[:company])
      @assignments = @assignments.where(company: company.self_and_descendants)
    end
    
    if params[:has_outcomes] == '1'
      @assignments = @assignments.joins(:assignment_outcomes).distinct
    end
    
    if params[:has_abilities] == '1'
      @assignments = @assignments.joins(:abilities).distinct
    end
    
    if params[:has_references] == '1'
      @assignments = @assignments.left_joins(:published_external_reference, :draft_external_reference)
                                 .where.not(published_external_references: { id: nil })
                                 .or(@assignments.left_joins(:published_external_reference, :draft_external_reference)
                                     .where.not(draft_external_references: { id: nil }))
                                 .distinct
    end
    
    # Filter by major version (using SQL LIKE for efficiency)
    if params[:major_version].present?
      major_version = params[:major_version].to_i
      @assignments = @assignments.where("semantic_version LIKE ?", "#{major_version}.%")
    end
    
    # Apply sorting
    case params[:sort]
    when 'title'
      @assignments = @assignments.order(:title)
    when 'title_desc'
      @assignments = @assignments.order(title: :desc)
    when 'company'
      @assignments = @assignments.joins(:company).order('organizations.display_name')
    when 'company_desc'
      @assignments = @assignments.joins(:company).order('organizations.display_name DESC')
    when 'outcomes'
      @assignments = @assignments.left_joins(:assignment_outcomes).group('assignments.id').order('COUNT(assignment_outcomes.id) DESC')
    when 'outcomes_desc'
      @assignments = @assignments.left_joins(:assignment_outcomes).group('assignments.id').order('COUNT(assignment_outcomes.id) ASC')
    when 'abilities'
      @assignments = @assignments.left_joins(:abilities).group('assignments.id').order('COUNT(assignment_abilities.id) DESC')
    when 'abilities_desc'
      @assignments = @assignments.left_joins(:abilities).group('assignments.id').order('COUNT(assignment_abilities.id) ASC')
    else
      @assignments = @assignments.ordered
    end
    
    render layout: 'authenticated-horizontal-navigation'
  end

  def show
    authorize @assignment
    render layout: 'authenticated-horizontal-navigation'
  end

  def new
    @assignment = @organization.assignments.build
    @assignment_decorator = AssignmentDecorator.new(@assignment)
    @form = AssignmentForm.new(@assignment)
    @form.current_person = current_person
    @form.instance_variable_set(:@form_data_empty, true)
    authorize @assignment
    render layout: 'authenticated-horizontal-navigation'
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
    render layout: 'authenticated-horizontal-navigation'
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
      render :edit, status: :unprocessable_entity
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
      company: params[:company],
      has_outcomes: params[:has_outcomes],
      has_abilities: params[:has_abilities],
      has_references: params[:has_references],
      major_version: params[:major_version],
      sort: params[:sort] || 'title',
      direction: params[:direction] || 'asc',
      view: params[:view] || 'table',
      spotlight: params[:spotlight] || 'none'
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
    redirect_params = params.except(:controller, :action, :utf8, :_method, :commit).permit!.to_h
    redirect_to organization_assignments_path(@organization, redirect_params)
  end

  private

  def set_organization
    @organization = Organization.find(params[:organization_id])
  end

  def set_assignment
    @assignment = @organization.assignments.find(params[:id])
  end

  def assignment_params
    params.require(:assignment).permit(:title, :tagline, :required_activities, :handbook, :department_id, :version_type)
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
