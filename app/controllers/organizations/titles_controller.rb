class Organizations::TitlesController < Organizations::OrganizationNamespaceBaseController
  before_action :set_title, only: [:show, :edit, :update, :destroy, :clone_positions]
  after_action :verify_authorized

  def index
    authorize @organization, :view_titles?
    respond_to do |format|
      format.html { redirect_to organization_positions_path(@organization) }
      format.json { render json: @organization.titles.ordered }
    end
  end

  def show
    authorize @title
    
    # Load teammates with active employment tenures on any position with this title
    # Get all tenures, then group by teammate and take the first one for each, preserving order
    all_tenures = EmploymentTenure
      .active
      .joins(:position, company_teammate: :person)
      .where(positions: { title_id: @title.id })
      .includes(company_teammate: :person, position: [:title, :position_level])
      .order('people.last_name, people.first_name, employment_tenures.started_at DESC')
    
    # Group by teammate_id and take the first (most recent) tenure for each teammate
    # Preserve the order by sorting the grouped results by the original order
    grouped = all_tenures.to_a.group_by(&:teammate_id)
    @teammates_with_title = all_tenures.to_a.uniq(&:teammate_id)
  end

  def new
    @title = Title.new(company: @organization)
    authorize @organization, :manage_maap?
  end

  def edit
    authorize @title
  end

  def create
    authorize @organization, :manage_maap?
    @title = Title.new(title_params)
    @title.company = company

    result = TitleSaveService.create(title: @title, params: title_params)
    
    if result.ok?
      redirect_to organization_title_path(@organization, @title), notice: 'Title was successfully created.'
    else
      @title.errors.add(:base, result.error) if result.error.is_a?(String)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @title
    result = TitleSaveService.update(title: @title, params: title_params)
    
    if result.ok?
      redirect_to organization_title_path(@organization, @title), notice: 'Title was successfully updated.'
    else
      @title.errors.add(:base, result.error) if result.error.is_a?(String)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @title
    result = TitleSaveService.delete(title: @title)
    
    if result.ok?
      redirect_to organization_positions_path(@organization), notice: 'Title was successfully deleted.'
    else
      redirect_to organization_positions_path(@organization), alert: result.error
    end
  end

  def clone_positions
    authorize @title, :clone_positions?
    Rails.logger.info "Clone positions called with params: #{params.inspect}"
    
    source_position = Position.find(params[:source_position_id])
    Rails.logger.info "Source position: #{source_position.inspect}"
    
    # Ensure target_level_ids is an array
    target_level_ids = Array(params[:target_level_ids]).compact.reject(&:blank?)
    Rails.logger.info "Target level IDs: #{target_level_ids.inspect}"
    
    if target_level_ids.empty?
      Rails.logger.warn "No target level IDs provided"
      redirect_to organization_title_path(@organization, @title), alert: 'Please select at least one target level.'
      return
    end
    
    if source_position.title != @title
      Rails.logger.warn "Source title mismatch: #{source_position.title_id} vs #{@title.id}"
      redirect_to organization_title_path(@organization, @title), alert: 'Source position must belong to this title.'
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
        existing_position = Position.find_by(title: @title, position_level: level)
        if existing_position.present?
          Rails.logger.info "Position already exists for level #{level_id}"
          next
        end
        
        # Clone the position
        new_position = Position.new(
          title: @title,
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
              assignment_type: pa.assignment_type,
              min_estimated_energy: pa.min_estimated_energy,
              max_estimated_energy: pa.max_estimated_energy
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
      redirect_to organization_title_path(@organization, @title), notice: notice_msg
    else
      alert_msg = 'No new positions were created. They may already exist.'
      alert_msg += " Errors: #{errors.join('; ')}" if errors.any?
      redirect_to organization_title_path(@organization, @title), alert: alert_msg
    end
  end

  private

  def set_title
    @title = @organization.titles.find(params[:id])
  end

  def title_params
    params.require(:title).permit(:position_major_level_id, :external_title, :alternative_titles, :position_summary, :department_id)
  end
end
