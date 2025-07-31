class PositionsController < ApplicationController
  before_action :set_position, only: [:show, :edit, :update, :destroy]
  before_action :set_company
  before_action :set_related_data, only: [:new, :edit, :create, :update]

  def index
    if @company
      @positions = Position.for_company(@company).ordered.includes(:position_type, :position_level)
    else
      @positions = Position.none
    end
  end

  def show
  end

  def new
    @position = Position.new
  end

  def edit
  end

  def create
    @position = Position.new(position_params)
    if @position.save
      update_assignments(@position)
      update_external_references(@position)
      redirect_to @position, notice: 'Position was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @position.update(position_params)
      update_assignments(@position)
      update_external_references(@position)
      redirect_to @position, notice: 'Position was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @position.destroy
    redirect_to positions_path, notice: 'Position was successfully deleted.'
  end

  def position_levels
    position_type = PositionType.find_by(id: params[:position_type_id])
    if position_type
      levels = position_type.position_major_level.position_levels
      render json: levels.map { |level| { id: level.id, level_name: level.level_name } }
    else
      render json: []
    end
  end

  private

  def set_position
    @position = Position.find(params[:id])
  end

  def set_company
    @company = if current_organization&.company?
      current_organization
    elsif current_organization&.respond_to?(:root_company)
      current_organization.root_company
    else
      # Fallback to current_organization if it's already a company
      current_organization
    end
  end

  def set_related_data
    @position_types = PositionType.where(organization: @company).ordered
    @assignments = Assignment.where(company: @company).ordered
    @position_levels = if params[:position_type_id]
      pt = PositionType.find_by(id: params[:position_type_id])
      pt&.position_major_level&.position_levels || []
    elsif @position&.position_type
      @position.position_type.position_major_level.position_levels
    else
      []
    end
  end

  def position_params
    params.require(:position).permit(:position_type_id, :position_level_id, :position_summary)
  end

  def update_assignments(position)
    position.position_assignments.destroy_all
    if params[:required_assignment_ids]
      params[:required_assignment_ids].each do |aid|
        position.position_assignments.create!(assignment_id: aid, assignment_type: 'required')
      end
    end
    if params[:suggested_assignment_ids]
      params[:suggested_assignment_ids].each do |aid|
        position.position_assignments.create!(assignment_id: aid, assignment_type: 'suggested')
      end
    end
  end

  def update_external_references(position)
    # Update or create published reference
    if params[:position][:published_source_url].present?
      if position.published_external_reference
        position.published_external_reference.update!(url: params[:position][:published_source_url])
      else
        position.create_published_external_reference!(url: params[:position][:published_source_url], reference_type: 'published')
      end
    elsif position.published_external_reference
      position.published_external_reference.destroy
    end
    
    # Update or create draft reference
    if params[:position][:draft_source_url].present?
      if position.draft_external_reference
        position.draft_external_reference.update!(url: params[:position][:draft_source_url])
      else
        position.create_draft_external_reference!(url: params[:position][:draft_source_url], reference_type: 'draft')
      end
    elsif position.draft_external_reference
      position.draft_external_reference.destroy
    end
  end
end
