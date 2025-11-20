class Organizations::PositionsController < ApplicationController
  before_action :set_organization
  before_action :set_position, only: [:show, :job_description, :edit, :update, :destroy]
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
    
    render layout: 'authenticated-v2-0'
  end

  def show
    render layout: 'authenticated-v2-0'
  end

  def job_description
    render layout: 'authenticated-v2-0'
  end

  def new
    @position = Position.new
    if params[:position_type_id]
      @position.position_type_id = params[:position_type_id]
      # Pre-populate position levels based on the selected position type
      position_type = PositionType.find(params[:position_type_id])
      @position_levels = position_type.position_major_level.position_levels
    end
    @position_decorator = PositionDecorator.new(@position)
    @form = PositionForm.new(@position)
    @form.current_person = current_person
    @form.instance_variable_set(:@form_data_empty, true)
    render layout: 'authenticated-v2-0'
  end

  def create
    @position = Position.new
    @position_decorator = PositionDecorator.new(@position)
    @form = PositionForm.new(@position)
    @form.current_person = current_person
    
    # Set flag for empty form data validation
    position_params_hash = position_params || {}
    @form.instance_variable_set(:@form_data_empty, position_params_hash.empty?)

    if @form.validate(position_params) && @form.save
      redirect_to organization_position_path(@organization, @position), notice: 'Position was successfully created.'
    else
      set_related_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @position_decorator = PositionDecorator.new(@position)
    @form = PositionForm.new(@position)
    @form.current_person = current_person
    render layout: 'authenticated-v2-0'
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
      render json: @position_levels.map { |level| { id: level.id, level: level.level } }
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

  private

  def set_organization
    @organization = Organization.find(params[:organization_id])
  end

  def set_position
    @position = @organization.positions.find(params[:id])
  end

  def set_related_data
    @position_types = PositionType.joins(:organization).where(organizations: { id: @organization.id })
    
    # Set position levels based on current position's type, or empty if no position
    if @position&.position_type
      @position_levels = @position.position_type.position_major_level.position_levels
    else
      @position_levels = []
    end
    
    @assignments = @organization.assignments.ordered
  end

  def position_params
    params.require(:position).permit(:position_type_id, :position_level_id, :external_title, :position_summary, :eligibility_requirements_summary, :version_type)
  end
end
