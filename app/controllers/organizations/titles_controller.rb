class Organizations::TitlesController < Organizations::OrganizationNamespaceBaseController
  before_action :set_title, only: [:show, :edit, :update, :destroy, :clone_positions, :archive, :execute_archive, :restore, :manage_paths, :update_paths, :refresh_expectation_alignment_score]
  before_action :load_titles_for_header_switcher, only: [:show, :edit, :update]
  after_action :verify_authorized

  def index
    authorize @organization, :view_titles?
    respond_to do |format|
      format.html { redirect_to organization_positions_path(@organization) }
      format.json { render json: @organization.titles.unarchived.ordered }
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
      .includes(:seat, company_teammate: :person, position: [:title, :position_level])
      .order('people.last_name, people.first_name, employment_tenures.started_at DESC')
    
    # Group by teammate_id and take the first (most recent) tenure for each teammate
    # Preserve the order by sorting the grouped results by the original order
    grouped = all_tenures.to_a.group_by(&:teammate_id)
    @teammates_with_title = all_tenures.to_a.uniq(&:teammate_id)

    @inbound_title_paths = @title.inbound_title_paths.includes(from_title: :position_major_level).sort_by { |p| p.from_title.external_title.to_s.downcase }
    @outbound_title_paths = @title.outbound_title_paths.includes(to_title: :position_major_level).sort_by { |p| p.to_title.external_title.to_s.downcase }
    @title_path_neighborhood = Titles::PathNeighborhoodGraph.new(title: @title, organization: @organization)
    @expectation_alignment_score = Titles::ExpectationAlignmentScore.for_viewer(
      title: @title,
      viewer: current_company_teammate,
      organization: @organization
    )
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

  def archive
    authorize @title, :archive?
    @blocking_positions = @title.blocking_positions.includes(:position_level).order('position_levels.level')
    @blocking_seats = @title.blocking_seats.includes(:title, :titles).ordered
    @blocking_title_paths = @title.blocking_title_paths.includes(:from_title, :to_title)
    @archivable = @title.archivable?
  end

  def execute_archive
    authorize @title, :archive?
    unless @title.archivable?
      redirect_to archive_organization_title_path(@organization, @title),
                  alert: 'Cannot archive: archive or clear all positions, seats, and title paths that use this title first.'
      return
    end

    @title.archive!
    redirect_to organization_title_path(@organization, @title), notice: 'Title was successfully archived.'
  end

  def restore
    authorize @title, :restore?
    @title.restore!
    redirect_to organization_title_path(@organization, @title), notice: 'Title was successfully restored.'
  end

  def manage_paths
    authorize @title, :manage_paths?
    load_path_manager_collections
    @return_url = organization_title_path(@organization, @title)
    @return_text = "Back to Title"
    render layout: "overlay"
  end

  def update_paths
    authorize @title, :manage_paths?

    result = Titles::PathManager.call(
      title: @title,
      end_cap: params[:end_cap],
      associations: title_paths_params
    )

    if result.ok?
      redirect_to organization_title_path(@organization, @title), notice: "Title paths were successfully updated."
    else
      flash.now[:alert] = result.error
      load_path_manager_collections
      @return_url = organization_title_path(@organization, @title)
      @return_text = "Back to Title"
      render :manage_paths, layout: "overlay", status: :unprocessable_entity
    end
  end

  def refresh_expectation_alignment_score
    authorize @title, :refresh_expectation_alignment_score?
    TitleExpectationAlignmentScoreRefreshJob.perform_later(@title.id)
    redirect_to organization_title_path(@organization, @title),
                notice: "Expectation Alignment Score refresh queued. Positions under this title are recalculated first, then the title score. Refresh this page in a moment."
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
      redirect_to clone_positions_redirect_path, alert: 'Please select at least one target level.'
      return
    end
    
    if source_position.title != @title
      Rails.logger.warn "Source title mismatch: #{source_position.title_id} vs #{@title.id}"
      redirect_to clone_positions_redirect_path, alert: 'Source position must belong to this title.'
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
    
    redirect_after_clone = clone_positions_redirect_path

    if created_count > 0
      notice_msg = "Successfully created #{created_count} new position(s)."
      notice_msg += " Errors: #{errors.join('; ')}" if errors.any?
      redirect_to redirect_after_clone, notice: notice_msg
    else
      alert_msg = 'No new positions were created. They may already exist.'
      alert_msg += " Errors: #{errors.join('; ')}" if errors.any?
      redirect_to redirect_after_clone, alert: alert_msg
    end
  end

  private

  def load_titles_for_header_switcher
    @titles_by_department = titles_by_department_for_switcher(company)
  end

  def titles_by_department_for_switcher(org)
    titles = org.titles
      .unarchived
      .includes(:department, :position_major_level)
      .left_joins(:department)
      .order(
        Arel.sql('CASE WHEN titles.department_id IS NULL THEN 0 ELSE 1 END'),
        'departments.name',
        'titles.external_title'
      )

    groups = titles.group_by { |t| t.department&.display_name || 'Company-wide' }
    result = {}
    result['Company-wide'] = groups['Company-wide'] if groups['Company-wide'].present?
    (groups.keys - ['Company-wide']).sort.each do |label|
      result[label] = groups[label]
    end
    result
  end

  def set_title
    @title = @organization.titles.find(params[:id])
  end

  def clone_positions_redirect_path
    if params[:return_to].to_s == 'positions'
      organization_positions_path(@organization)
    else
      organization_title_path(@organization, @title)
    end
  end

  def title_params
    params.require(:title).permit(
      :position_major_level_id,
      :external_title,
      :alternative_titles,
      :position_summary,
      :department_id,
      :job_description_disclaimer,
      :work_environment,
      :physical_requirements,
      :travel
    )
  end

  def load_path_manager_collections
    @inbound_title_paths = @title.inbound_title_paths.includes(from_title: :position_major_level).sort_by { |p| p.from_title.external_title.to_s.downcase }
    @outbound_title_paths = @title.outbound_title_paths.includes(to_title: :position_major_level).sort_by { |p| p.to_title.external_title.to_s.downcase }

    @existing_paths_by_title_id = {}
    @inbound_title_paths.each { |path| @existing_paths_by_title_id[path.from_title_id] = path }
    @outbound_title_paths.each { |path| @existing_paths_by_title_id[path.to_title_id] = path }

    associated_ids = @existing_paths_by_title_id.keys
    @associated_titles = Title.unarchived.where(id: associated_ids).includes(:department, :position_major_level).ordered.to_a
    @associated_titles.sort_by! { |t| t.external_title.to_s.downcase }

    @available_titles = @organization.titles
      .unarchived
      .where.not(id: associated_ids + [@title.id])
      .includes(:department, :position_major_level)
      .ordered
  end

  def title_paths_params
    raw = params[:title_paths]
    return {} if raw.blank?

    permitted = raw.permit!
    result = {}
    permitted.each do |other_title_id, attrs|
      next if other_title_id.blank?

      result[other_title_id.to_i] = {
        direction: attrs[:direction],
        path_type: attrs[:path_type]
      }
    end
    result
  end
end
