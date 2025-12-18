class Organizations::PositionsController < ApplicationController
  before_action :set_organization
  before_action :set_position, only: [:show, :job_description, :edit, :update, :destroy, :manage_assignments, :update_assignments]
  before_action :set_related_data, only: [:new, :edit, :create, :update]

  def index
    @positions = @organization.positions.includes(:position_type, :position_level)
    
    # Apply filters
    @positions = @positions.where(position_type_id: params[:position_type]) if params[:position_type].present?
    @positions = @positions.where(position_level_id: params[:position_level]) if params[:position_level].present?
    
    # Filter by major version (using SQL LIKE for efficiency)
    if params[:major_version].present?
      major_version = params[:major_version].to_i
      @positions = @positions.where("semantic_version LIKE ?", "#{major_version}.%")
    end
    
    # Apply sorting
    case params[:sort]
    when 'name'
      @positions = @positions.joins(:position_type).order('position_types.external_title')
    when 'level'
      @positions = @positions.joins(:position_level).order('position_levels.level')
    when 'assignments'
      @positions = @positions.left_joins(:position_assignments).group('positions.id').order('COUNT(position_assignments.id) DESC')
    when 'created_at'
      @positions = @positions.order(created_at: :desc)
    when 'created_at_asc'
      @positions = @positions.order(created_at: :asc)
    else
      @positions = @positions.ordered
    end
    
    # Apply direction if specified
    if params[:direction] == 'desc'
      case params[:sort]
      when 'name'
        @positions = @positions.joins(:position_type).order('position_types.external_title DESC')
      when 'level'
        @positions = @positions.joins(:position_level).order('position_levels.level DESC')
      end
    end
    
    @position_types = @organization.position_types.includes(:positions, :position_major_level).order(:external_title)
    
    render layout: determine_layout
  end

  def show
    render layout: determine_layout
  end

  def job_description
    render layout: determine_layout
  end

  def new
    unless params[:position_type_id].present?
      redirect_to organization_positions_path(@organization), alert: 'Position type is required to create a position.'
      return
    end
    
    @position = Position.new
    @position.position_type_id = params[:position_type_id]
    @position_type = PositionType.find(params[:position_type_id])
    
    # Ensure the position type belongs to the organization
    unless @position_type.organization == @organization
      redirect_to organization_positions_path(@organization), alert: 'Invalid position type for this organization.'
      return
    end
    
    # Pre-populate position levels based on the selected position type
    @position_levels = @position_type.position_major_level.position_levels
    
    @position_decorator = PositionDecorator.new(@position)
    @form = PositionForm.new(@position)
    @form.current_person = current_person
    @form.instance_variable_set(:@form_data_empty, true)
    render layout: determine_layout
  end

  def create
    # Get position_type_id from params or from position_params
    position_type_id = params[:position_type_id] || position_params[:position_type_id]
    
    unless position_type_id.present?
      redirect_to organization_positions_path(@organization), alert: 'Position type is required to create a position.'
      return
    end
    
    @position = Position.new
    @position.position_type_id = position_type_id
    @position_type = PositionType.find(position_type_id)
    
    # Ensure the position type belongs to the organization
    unless @position_type.organization == @organization
      redirect_to organization_positions_path(@organization), alert: 'Invalid position type for this organization.'
      return
    end
    
    @position_decorator = PositionDecorator.new(@position)
    @form = PositionForm.new(@position)
    @form.current_person = current_person
    
    # Set flag for empty form data validation
    position_params_hash = position_params || {}
    @form.instance_variable_set(:@form_data_empty, position_params_hash.empty?)

    if @form.validate(position_params) && @form.save
      redirect_to organization_position_path(@organization, @position), notice: 'Position was successfully created.'
    else
      @position_levels = @position_type.position_major_level.position_levels
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @position_decorator = PositionDecorator.new(@position)
    @form = PositionForm.new(@position)
    @form.current_person = current_person
    render layout: determine_layout
  end

  def update
    @position_decorator = PositionDecorator.new(@position)
    @form = PositionForm.new(@position)
    @form.current_person = current_person
    
    # Set flag for empty form data validation
    position_params_hash = position_params || {}
    @form.instance_variable_set(:@form_data_empty, position_params_hash.empty?)

    if @form.validate(position_params) && @form.save
      redirect_to organization_position_path(@organization, @position), notice: 'Position was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @position.destroy
    redirect_to organization_positions_path(@organization), notice: 'Position was successfully deleted.'
  end

  def position_levels
    if params[:position_type_id].present?
      position_type = PositionType.find(params[:position_type_id])
      @position_levels = position_type.position_major_level.position_levels
      render json: @position_levels.map { |level| { id: level.id, level: level.level, level_name: level.level_name } }
    else
      render json: []
    end
  end

  def customize_view
    authorize @organization, :show?
    set_related_data
    
    # Load current state from params
    @current_filters = {
      position_type: params[:position_type],
      position_level: params[:position_level],
      major_version: params[:major_version],
      sort: params[:sort] || 'name',
      direction: params[:direction] || 'asc',
      view: params[:view] || 'table',
      spotlight: params[:spotlight] || 'none'
    }
    
    @current_sort = @current_filters[:sort]
    @current_view = @current_filters[:view]
    @current_spotlight = @current_filters[:spotlight]
    
    # Preserve current params for return URL
    return_params = params.except(:controller, :action, :page).permit!.to_h
    @return_url = organization_positions_path(@organization, return_params)
    @return_text = "Back to Positions"
    
    render layout: 'overlay'
  end

  def update_view
    authorize @organization, :show?
    
    # Build redirect URL with all view customization params
    redirect_params = params.except(:controller, :action, :utf8, :_method, :commit).permit!.to_h
    redirect_to organization_positions_path(@organization, redirect_params)
  end

  def manage_assignments
    authorize @position, :update?
    
    # Get position's company and all descendants
    company = @position.position_type.organization.root_company
    company_and_descendants = company.self_and_descendants
    
    # Load all assignments in company hierarchy
    @assignments = Assignment.where(company: company_and_descendants)
                            .includes(:department)
                            .ordered
    
    # Build nested structure: company > department > assignments
    @assignments_by_org = @assignments.group_by(&:department)
    
    # Get existing position assignments for pre-population
    @existing_position_assignments = @position.position_assignments.index_by(&:assignment_id)
    
    # Calculate totals for required and suggested assignments
    required_pas = @position.position_assignments.required
    suggested_pas = @position.position_assignments.suggested
    
    @required_totals = {
      min: required_pas.sum { |pa| pa.min_estimated_energy || 0 },
      max: required_pas.sum { |pa| pa.max_estimated_energy || 0 },
      anticipated: required_pas.sum { |pa| pa.anticipated_energy_percentage || 0 }
    }
    
    @suggested_totals = {
      min: suggested_pas.sum { |pa| pa.min_estimated_energy || 0 },
      max: suggested_pas.sum { |pa| pa.max_estimated_energy || 0 },
      anticipated: suggested_pas.sum { |pa| pa.anticipated_energy_percentage || 0 }
    }
    
    # Set return URL
    @return_url = organization_position_path(@organization, @position)
    @return_text = "Back to Position"
    
    render layout: 'overlay'
  end

  def update_assignments
    authorize @position, :update?
    
    position_assignments_params = params[:position_assignments] || {}
    assignment_ids_to_keep = []
    errors = []
    
    # Process each assignment in params
    position_assignments_params.each do |assignment_id_str, assignment_data|
      assignment_id = assignment_id_str.to_i
      max_energy = assignment_data[:max_estimated_energy].present? ? assignment_data[:max_estimated_energy].to_i : 0
      
      # Skip if max_estimated_energy is 0 or not set
      next if max_energy <= 0
      
      assignment_ids_to_keep << assignment_id
      
      # Find or initialize PositionAssignment
      position_assignment = @position.position_assignments.find_or_initialize_by(assignment_id: assignment_id)
      
      # Update attributes
      min_energy = assignment_data[:min_estimated_energy].present? ? assignment_data[:min_estimated_energy].to_i : nil
      anticipated_energy = assignment_data[:anticipated_energy_percentage].present? ? assignment_data[:anticipated_energy_percentage].to_i : nil
      
      position_assignment.min_estimated_energy = min_energy
      position_assignment.max_estimated_energy = max_energy
      position_assignment.anticipated_energy_percentage = anticipated_energy
      position_assignment.assignment_type = assignment_data[:assignment_type] || 'required'
      
      unless position_assignment.save
        errors << "Failed to save assignment #{assignment_id}: #{position_assignment.errors.full_messages.join(', ')}"
      end
    end
    
    # Destroy position assignments that are no longer in params or have max_energy = 0
    assignments_to_destroy = @position.position_assignments.where.not(assignment_id: assignment_ids_to_keep)
    assignments_to_destroy.destroy_all
    
    if errors.any?
      redirect_to manage_assignments_organization_position_path(@organization, @position), alert: "Some assignments could not be saved: #{errors.join('; ')}"
    else
      redirect_to manage_assignments_organization_position_path(@organization, @position), notice: 'Assignments updated successfully.'
    end
  end

  private

  def set_organization
    @organization = Organization.find(params[:organization_id])
  end

  def set_position
    @position = @organization.positions.find(params[:id])
  end

  def set_related_data
    @position_types = PositionType.joins(:organization, :position_major_level)
                                  .where(organizations: { id: @organization.id })
                                  .order('position_major_levels.major_level, position_types.external_title')
    
    # Set position levels based on current position's type, or from position_type_id param
    if @position&.position_type
      @position_levels = @position.position_type.position_major_level.position_levels
      @position_type = @position.position_type
    elsif params[:position_type_id].present?
      @position_type = PositionType.find_by(id: params[:position_type_id], organization: @organization)
      @position_levels = @position_type&.position_major_level&.position_levels || []
    else
      @position_levels = []
    end
    
    @assignments = @organization.assignments.ordered
  end

  def position_params
    params.require(:position).permit(:position_level_id, :external_title, :position_summary, :eligibility_requirements_summary, :version_type)
  end
end
