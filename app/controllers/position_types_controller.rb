class PositionTypesController < ApplicationController
  before_action :set_position_type, only: [:show, :edit, :update, :destroy, :clone_positions]
  before_action :set_organization

  def index
    @position_types = PositionType.where(organization: @organization).ordered
    respond_to do |format|
      format.html
      format.json { render json: @position_types }
    end
  end

  def show
  end

  def new
    @position_type = PositionType.new(organization: @organization)
  end

  def edit
  end

  def create
    @position_type = PositionType.new(position_type_params)
    @position_type.organization = @organization

    if @position_type.save
      redirect_to @position_type, notice: 'Position type was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @position_type.update(position_type_params)
      redirect_to @position_type, notice: 'Position type was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @position_type.destroy
    redirect_to position_types_path, notice: 'Position type was successfully deleted.'
  end

  def clone_positions
    source_position = Position.find(params[:source_position_id])
    target_level_ids = params[:target_level_ids]
    
    if source_position.position_type != @position_type
      redirect_to @position_type, alert: 'Source position must belong to this position type.'
      return
    end
    
    created_count = 0
    target_level_ids.each do |level_id|
      level = PositionLevel.find(level_id)
      
      # Check if position already exists for this level
      existing_position = Position.find_by(position_type: @position_type, position_level: level)
      next if existing_position.present?
      
      # Clone the position
      new_position = Position.new(
        position_type: @position_type,
        position_level: level,
        position_summary: source_position.position_summary
      )
      
      if new_position.save
        # Clone assignments
        source_position.position_assignments.each do |pa|
          new_position.position_assignments.create!(
            assignment: pa.assignment,
            assignment_type: pa.assignment_type
          )
        end
        
        # Clone external references
        if source_position.published_external_reference
          new_position.create_published_external_reference!(
            url: source_position.published_external_reference.url,
            reference_type: 'published'
          )
        end
        
        if source_position.draft_external_reference
          new_position.create_draft_external_reference!(
            url: source_position.draft_external_reference.url,
            reference_type: 'draft'
          )
        end
        
        created_count += 1
      end
    end
    
    if created_count > 0
      redirect_to @position_type, notice: "Successfully created #{created_count} new position(s)."
    else
      redirect_to @position_type, alert: 'No new positions were created. They may already exist.'
    end
  end

  private

  def set_position_type
    @position_type = PositionType.find(params[:id])
  end

  def set_organization
    @organization = current_organization
  end

  def position_type_params
    params.require(:position_type).permit(:position_major_level_id, :external_title, :alternative_titles, :position_summary)
  end
end
