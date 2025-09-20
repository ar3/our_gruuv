class PositionTypesController < ApplicationController
  layout 'authenticated-v2-0'
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
    Rails.logger.info "Clone positions called with params: #{params.inspect}"
    
    source_position = Position.find(params[:source_position_id])
    Rails.logger.info "Source position: #{source_position.inspect}"
    
    # Ensure target_level_ids is an array
    target_level_ids = Array(params[:target_level_ids]).compact.reject(&:blank?)
    Rails.logger.info "Target level IDs: #{target_level_ids.inspect}"
    
    if target_level_ids.empty?
      Rails.logger.warn "No target level IDs provided"
      redirect_to @position_type, alert: 'Please select at least one target level.'
      return
    end
    
    if source_position.position_type != @position_type
      Rails.logger.warn "Source position type mismatch: #{source_position.position_type_id} vs #{@position_type.id}"
      redirect_to @position_type, alert: 'Source position must belong to this position type.'
      return
    end
    
    created_count = 0
    errors = []
    
    target_level_ids.each do |level_id|
      Rails.logger.info "Processing level ID: #{level_id}"
      
      begin
        level = PositionLevel.find(level_id)
        Rails.logger.info "Found level: #{level.inspect}"
        
        # Check if position already exists for this level
        existing_position = Position.find_by(position_type: @position_type, position_level: level)
        if existing_position.present?
          Rails.logger.info "Position already exists for level #{level_id}"
          next
        end
        
        # Clone the position
        new_position = Position.new(
          position_type: @position_type,
          position_level: level,
          position_summary: source_position.position_summary
        )
        
        Rails.logger.info "Attempting to save new position: #{new_position.attributes}"
        
        if new_position.save
          Rails.logger.info "Successfully created position: #{new_position.id}"
          
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
        else
          error_msg = "Failed to save position for level #{level_id}: #{new_position.errors.full_messages.join(', ')}"
          Rails.logger.error error_msg
          errors << error_msg
        end
      rescue ActiveRecord::RecordNotFound => e
        error_msg = "Position level #{level_id} not found"
        Rails.logger.error error_msg
        errors << error_msg
      rescue => e
        error_msg = "Error processing level #{level_id}: #{e.message}"
        Rails.logger.error error_msg
        errors << error_msg
      end
    end
    
    Rails.logger.info "Clone positions completed. Created: #{created_count}, Errors: #{errors.inspect}"
    
    if created_count > 0
      notice_msg = "Successfully created #{created_count} new position(s)."
      notice_msg += " Errors: #{errors.join('; ')}" if errors.any?
      redirect_to @position_type, notice: notice_msg
    else
      alert_msg = 'No new positions were created. They may already exist.'
      alert_msg += " Errors: #{errors.join('; ')}" if errors.any?
      redirect_to @position_type, alert: alert_msg
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
