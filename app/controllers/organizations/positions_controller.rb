class Organizations::PositionsController < ApplicationController
  before_action :set_organization
  before_action :set_position, only: [:show, :job_description, :edit, :update, :destroy]
  before_action :set_related_data, only: [:new, :edit, :create, :update]

  def index
    @positions = @organization.positions.includes(:position_type, :position_level).ordered
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
    render layout: 'authenticated-v2-0'
  end

  def create
    @position = Position.new(position_params)
    @position.position_type = PositionType.find(position_params[:position_type_id]) if position_params[:position_type_id].present?
    @position.position_level = PositionLevel.find(position_params[:position_level_id]) if position_params[:position_level_id].present?

    if @position.save
      redirect_to organization_position_path(@organization, @position), notice: 'Position was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    render layout: 'authenticated-v2-0'
  end

  def update
    if @position.update(position_params)
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
    params.require(:position).permit(:position_type_id, :position_level_id, :external_title, :position_summary)
  end
end
