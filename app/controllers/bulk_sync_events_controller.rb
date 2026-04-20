class BulkSyncEventsController < Organizations::OrganizationNamespaceBaseController
  before_action :require_login
  before_action :set_bulk_sync_event, only: [:show, :destroy, :process_sync]
  before_action :authorize_bulk_sync_events, only: [:new, :create, :run_auto_refresh_slack]

  def index
    authorize company, :view_bulk_sync_events?
    @selected_statuses = Array(params[:statuses]).reject(&:blank?)
    @selected_sync_types = Array(params[:sync_types]).reject(&:blank?)
    @selected_sources = Array(params[:sources]).reject(&:blank?)
    @selected_creators = Array(params[:creators]).reject(&:blank?)
    @selected_sort = params[:sort].presence || 'created_desc'
    @current_view = params[:view].presence || 'table'
    @current_spotlight = params[:spotlight].presence || 'bulk_sync_data_overview'

    @bulk_sync_events = policy_scope(BulkSyncEvent)
                        .includes(:creator, :initiator)

    if @selected_statuses.any?
      @bulk_sync_events = @bulk_sync_events.where(status: @selected_statuses)
    end

    if @selected_sync_types.any?
      @bulk_sync_events = @bulk_sync_events.where(type: @selected_sync_types)
    end

    if @selected_creators.any?
      creator_ids = @selected_creators.map { |id| id == 'system' ? nil : id.to_i }
      if creator_ids.include?(nil)
        ids_without_nil = creator_ids.compact
        @bulk_sync_events = if ids_without_nil.any?
                              @bulk_sync_events.where(creator_id: ids_without_nil).or(@bulk_sync_events.where(creator_id: nil))
                            else
                              @bulk_sync_events.where(creator_id: nil)
                            end
      else
        @bulk_sync_events = @bulk_sync_events.where(creator_id: creator_ids)
      end
    end

    if @selected_sources.any?
      source_scopes = []
      source_scopes << @bulk_sync_events.where("source_data ->> 'type' = 'file_upload'") if @selected_sources.include?('file_upload')
      source_scopes << @bulk_sync_events.where("source_data ->> 'type' = 'slack_sync'") if @selected_sources.include?('slack_sync')
      source_scopes << @bulk_sync_events.where("source_data ->> 'type' = 'database_sync'") if @selected_sources.include?('database_sync')
      source_scopes << @bulk_sync_events.where("source_data ->> 'sync_mode' = 'daily'") if @selected_sources.include?('daily_auto')
      source_scopes << @bulk_sync_events.where("source_data ->> 'sync_mode' = 'manual'") if @selected_sources.include?('manual_auto')
      @bulk_sync_events = source_scopes.reduce { |combined, scope| combined.or(scope) } if source_scopes.any?
    end

    @bulk_sync_events = case @selected_sort
                        when 'created_asc'
                          @bulk_sync_events.order(created_at: :asc)
                        when 'status_asc'
                          @bulk_sync_events.order(status: :asc, created_at: :desc)
                        when 'status_desc'
                          @bulk_sync_events.order(status: :desc, created_at: :desc)
                        when 'type_asc'
                          @bulk_sync_events.order(type: :asc, created_at: :desc)
                        when 'type_desc'
                          @bulk_sync_events.order(type: :desc, created_at: :desc)
                        else
                          @bulk_sync_events.order(created_at: :desc)
                        end

    @creator_options = policy_scope(BulkSyncEvent)
                       .includes(:creator)
                       .where.not(creator_id: nil)
                       .map(&:creator)
                       .compact
                       .uniq { |creator| creator.id }
                       .sort_by(&:display_name)

    @filters_summary = build_filters_summary
    @sort_summary = sort_label(@selected_sort)
    @view_summary = view_label(@current_view)
    @spotlight_summary = spotlight_label(@current_spotlight)
    
    # Spotlight statistics
    @spotlight_stats = {
      total_syncs: @bulk_sync_events.count,
      completed_syncs: @bulk_sync_events.completed.count,
      ready_for_preview: @bulk_sync_events.preview.count,
      failed_syncs: @bulk_sync_events.failed.count,
      processing_syncs: @bulk_sync_events.processing.count,
      recent_syncs: @bulk_sync_events.where('created_at > ?', 7.days.ago).count,
      assignment_checkins: @bulk_sync_events.where(type: ['UploadAssignmentCheckins', 'BulkSyncEvent::UploadAssignmentCheckins']).count,
      employee_uploads: @bulk_sync_events.where(type: ['UploadEmployees', 'BulkSyncEvent::UploadEmployees']).count,
      assignments_and_abilities: @bulk_sync_events.where(type: 'BulkSyncEvent::UploadAssignmentsAndAbilities').count,
      refresh_names: @bulk_sync_events.where(type: 'BulkSyncEvent::RefreshNamesSync').count,
      refresh_slack: @bulk_sync_events.where(type: 'BulkSyncEvent::RefreshSlackSync').count,
      ensure_assignment_tenures: @bulk_sync_events.where(type: 'BulkSyncEvent::EnsureAssignmentTenuresSync').count
    }
  end

  def show
    authorize @bulk_sync_event, :show?
    # Show page displays sync details, preview actions, and results
  end

  def new
    type_param = params.dig(:bulk_sync_event, :type)
    
    if type_param.blank?
      redirect_to organization_bulk_sync_events_path(current_organization), alert: 'Please select a sync type from the dropdown.'
      return
    end
    
    begin
      @bulk_sync_event = type_param.constantize.new
    rescue NameError
      redirect_to organization_bulk_sync_events_path(current_organization), alert: 'Invalid sync type selected.'
      return
    end
  end

  def create
    form = BulkSyncEventForm.new(
      type: params.dig(:bulk_sync_event, :type),
      file: params.dig(:bulk_sync_event, :file),
      organization_id: current_organization.id,
      creator_id: current_person.id,
      initiator_id: current_person.id
    )

    begin
      if form.save
        redirect_to organization_bulk_sync_event_path(current_organization, form.bulk_sync_event), notice: 'Sync created successfully. Please review the preview before processing.'
      else
        @bulk_sync_event = form.bulk_sync_event || form.type&.constantize&.new
        @errors = form.errors
        if form.parse_error_message.present?
          flash.now[:alert] = form.parse_error_message
        end
        render :new, status: :unprocessable_entity
      end
    rescue => e
      # Log the error and always re-raise so it's visible and not swallowed
      Rails.logger.error "❌❌❌ BulkSyncEventsController: Exception creating bulk sync event: #{e.class.name} - #{e.message}"
      Rails.logger.error "❌❌❌ BulkSyncEventsController: Backtrace: #{e.backtrace.first(20).join("\n")}" if e.backtrace
      # Always re-raise the exception so it's visible
      raise e
    end
  end

  def run_auto_refresh_slack
    RefreshSlackIdentitiesAutoSyncJob.perform_later(
      current_organization.id,
      current_person.id,
      current_person.id,
      'manual'
    )

    redirect_to organization_bulk_sync_events_path(current_organization),
                notice: 'Auto refresh Slack sync started. Results will appear in Bulk Sync Events when complete.'
  end

  def destroy
    if @bulk_sync_event.can_destroy?
      @bulk_sync_event.destroy
      redirect_to organization_bulk_sync_events_path(current_organization), notice: 'Sync deleted successfully.'
    else
      redirect_to organization_bulk_sync_event_path(current_organization, @bulk_sync_event), alert: 'Cannot delete this sync.'
    end
  end

  def process_sync
    authorize @bulk_sync_event, :process_sync?
    
    unless @bulk_sync_event.can_process?
      redirect_to organization_bulk_sync_event_path(current_organization, @bulk_sync_event), alert: 'This sync cannot be processed.'
      return
    end

    # Filter preview actions based on selected items
    filtered_preview_actions = filter_preview_actions_by_selection(@bulk_sync_event.preview_actions, params)
    
    # Update the sync event with filtered actions
    @bulk_sync_event.update!(preview_actions: filtered_preview_actions)

    # Process the sync inline and get the result
    begin
      result = case @bulk_sync_event.type
      when 'BulkSyncEvent::UploadEmployees', 'UploadEvent::UploadEmployees'
        Rails.logger.debug "❌❌❌ BulkSyncEventsController: Using UnassignedEmployeeUploadProcessorJob"
        UnassignedEmployeeUploadProcessorJob.perform_and_get_result(@bulk_sync_event.id, current_organization.id)
      when 'BulkSyncEvent::UploadAssignmentCheckins', 'UploadEvent::UploadAssignmentCheckins'
        Rails.logger.debug "❌❌❌ BulkSyncEventsController: Using EmploymentDataUploadProcessorJob"
        EmploymentDataUploadProcessorJob.perform_and_get_result(@bulk_sync_event.id, current_organization.id)
      when 'BulkSyncEvent::UploadAssignmentsAndAbilities'
        Rails.logger.debug "❌❌❌ BulkSyncEventsController: Using AssignmentsAndAbilitiesUploadProcessorJob"
        AssignmentsAndAbilitiesUploadProcessorJob.perform_and_get_result(@bulk_sync_event.id, current_organization.id)
      when 'BulkSyncEvent::UploadAssignmentsBulk'
        Rails.logger.debug "❌❌❌ BulkSyncEventsController: Using AssignmentsBulkUploadProcessorJob"
        AssignmentsBulkUploadProcessorJob.perform_and_get_result(@bulk_sync_event.id, current_organization.id)
      when 'BulkSyncEvent::RefreshNamesSync'
        Rails.logger.debug "❌❌❌ BulkSyncEventsController: Using RefreshNamesSyncProcessorJob"
        RefreshNamesSyncProcessorJob.perform_and_get_result(@bulk_sync_event.id, current_organization.id)
      when 'BulkSyncEvent::RefreshSlackSync'
        Rails.logger.debug "❌❌❌ BulkSyncEventsController: Using RefreshSlackSyncProcessorJob"
        RefreshSlackSyncProcessorJob.perform_and_get_result(@bulk_sync_event.id, current_organization.id)
      when 'BulkSyncEvent::EnsureAssignmentTenuresSync'
        Rails.logger.debug "❌❌❌ BulkSyncEventsController: Using EnsureAssignmentTenuresSyncProcessorJob"
        EnsureAssignmentTenuresSyncProcessorJob.perform_and_get_result(@bulk_sync_event.id, current_organization.id)
      else
        Rails.logger.warn "❌❌❌ BulkSyncEventsController: Unknown type #{@bulk_sync_event.type}, using EmploymentDataUploadProcessorJob"
        EmploymentDataUploadProcessorJob.perform_and_get_result(@bulk_sync_event.id, current_organization.id)
      end
      
      if result
        redirect_to organization_bulk_sync_event_path(current_organization, @bulk_sync_event), notice: 'Sync processed successfully!'
      else
        redirect_to organization_bulk_sync_event_path(current_organization, @bulk_sync_event), alert: 'Sync processing failed. Please check the logs for details.'
      end
    rescue => e
      # Re-raise the exception so Rails can handle it and show it to the user
      Rails.logger.error "❌❌❌ BulkSyncEventsController: Exception processing bulk sync event #{@bulk_sync_event.id}: #{e.class.name} - #{e.message}"
      Rails.logger.error "❌❌❌ BulkSyncEventsController: Backtrace: #{e.backtrace.first(20).join("\n")}" if e.backtrace
      raise e
    end
  end

  private

  def build_filters_summary
    parts = []
    parts << "#{@selected_statuses.size} status#{'es' unless @selected_statuses.size == 1}" if @selected_statuses.any?
    parts << "#{@selected_sync_types.size} sync type#{'s' unless @selected_sync_types.size == 1}" if @selected_sync_types.any?
    parts << "#{@selected_sources.size} source#{'s' unless @selected_sources.size == 1}" if @selected_sources.any?
    parts << "#{@selected_creators.size} creator#{'s' unless @selected_creators.size == 1}" if @selected_creators.any?
    parts.any? ? parts.join(' / ') : 'None applied'
  end

  def sort_label(sort_value)
    case sort_value
    when 'created_desc'
      'Created Date (Newest First)'
    when 'created_asc'
      'Created Date (Oldest First)'
    when 'status_asc'
      'Status (A-Z)'
    when 'status_desc'
      'Status (Z-A)'
    when 'type_asc'
      'Type (A-Z)'
    when 'type_desc'
      'Type (Z-A)'
    else
      'Created Date (Newest First)'
    end
  end

  def view_label(view_value)
    case view_value
    when 'table'
      'Table'
    when 'cards'
      'Cards'
    when 'list'
      'List'
    else
      view_value.to_s.humanize
    end
  end

  def spotlight_label(spotlight_value)
    case spotlight_value
    when 'bulk_sync_data_overview'
      'Bulk Sync Data Overview'
    when 'none'
      'None'
    else
      spotlight_value.to_s.humanize
    end
  end

  def require_login
    unless current_person
      redirect_to root_path, alert: 'Please log in to access this page'
    end
  end

  def set_bulk_sync_event
    @bulk_sync_event = organization.bulk_sync_events.find(params[:id])
  end

  def bulk_sync_event_params
    params.require(:bulk_sync_event).permit()
  end

  def authorize_bulk_sync_events
    authorize BulkSyncEvent
  end

  def filter_preview_actions_by_selection(preview_actions, params)
    filtered = {}
    
    # Filter employment data fields
    if preview_actions['people'].present?
      selected_people_rows = Array(params[:selected_people]).map(&:to_i)
      filtered['people'] = preview_actions['people'].select { |p| selected_people_rows.include?(p['row']) }
    end
    
    if preview_actions['assignments'].present?
      selected_assignment_rows = Array(params[:selected_assignments]).map(&:to_i)
      filtered['assignments'] = preview_actions['assignments'].select { |a| selected_assignment_rows.include?(a['row']) }
    end
    
    if preview_actions['assignment_tenures'].present?
      selected_tenure_rows = Array(params[:selected_tenures]).map(&:to_i)
      filtered['assignment_tenures'] = preview_actions['assignment_tenures'].select { |t| selected_tenure_rows.include?(t['row']) }
    end
    
    if preview_actions['assignment_check_ins'].present?
      selected_check_in_rows = Array(params[:selected_check_ins]).map(&:to_i)
      filtered['assignment_check_ins'] = preview_actions['assignment_check_ins'].select { |c| selected_check_in_rows.include?(c['row']) }
    end
    
    if preview_actions['external_references'].present?
      selected_ref_rows = Array(params[:selected_external_refs]).map(&:to_i)
      filtered['external_references'] = preview_actions['external_references'].select { |r| selected_ref_rows.include?(r['row']) }
    end
    
    # Filter employee upload fields
    if preview_actions['unassigned_employees'].present?
      selected_employee_rows = Array(params[:selected_unassigned_employees]).map(&:to_i)
      filtered['unassigned_employees'] = preview_actions['unassigned_employees'].select { |e| selected_employee_rows.include?(e['row']) }
    end
    
    if preview_actions['departments'].present?
      selected_department_rows = Array(params[:selected_departments]).map(&:to_i)
      filtered['departments'] = preview_actions['departments'].select { |d| selected_department_rows.include?(d['row']) }
    end
    
    if preview_actions['managers'].present?
      selected_manager_rows = Array(params[:selected_managers]).map(&:to_i)
      filtered['managers'] = preview_actions['managers'].select { |m| selected_manager_rows.include?(m['row']) }
    end
    
    if preview_actions['titles'].present?
      selected_title_rows = Array(params[:selected_titles]).map(&:to_i)
      filtered['titles'] = preview_actions['titles'].select { |title| selected_title_rows.include?(title['row']) }
    end
    
    if preview_actions['positions'].present?
      selected_position_rows = Array(params[:selected_positions]).map(&:to_i)
      filtered['positions'] = preview_actions['positions'].select { |p| selected_position_rows.include?(p['row']) }
    end
    
    if preview_actions['teammates'].present?
      selected_teammate_rows = Array(params[:selected_teammates]).map(&:to_i)
      filtered['teammates'] = preview_actions['teammates'].select { |t| selected_teammate_rows.include?(t['row']) }
    end
    
    if preview_actions['employment_tenures'].present?
      selected_employment_tenure_rows = Array(params[:selected_employment_tenures]).map(&:to_i)
      filtered['employment_tenures'] = preview_actions['employment_tenures'].select { |et| selected_employment_tenure_rows.include?(et['row']) }
    end

    # Filter refresh names sync fields
    if preview_actions['preferred_name_updates'].present?
      selected_name_update_rows = Array(params[:selected_preferred_name_updates]).map(&:to_i)
      filtered['preferred_name_updates'] = preview_actions['preferred_name_updates'].select { |n| selected_name_update_rows.include?(n['row']) }
    end

    # Filter refresh slack sync fields
    if preview_actions['update_slack_identities'].present?
      selected_update_rows = Array(params[:selected_update_slack_identities]).map(&:to_i)
      filtered['update_slack_identities'] = preview_actions['update_slack_identities'].select { |u| selected_update_rows.include?(u['row']) }
    end

    if preview_actions['create_slack_associations'].present?
      selected_association_rows = Array(params[:selected_create_slack_associations]).map(&:to_i)
      filtered['create_slack_associations'] = preview_actions['create_slack_associations'].select { |a| selected_association_rows.include?(a['row']) }
    end

    if preview_actions['suggest_terminations'].present?
      selected_termination_rows = Array(params[:selected_suggest_terminations]).map(&:to_i)
      filtered['suggest_terminations'] = preview_actions['suggest_terminations'].select { |t| selected_termination_rows.include?(t['row']) }
    end

    # Filter ensure assignment tenures sync fields
    if preview_actions['assignment_tenures'].present?
      selected_assignment_tenure_rows = Array(params[:selected_assignment_tenures]).map(&:to_i)
      filtered['assignment_tenures'] = preview_actions['assignment_tenures'].select { |at| selected_assignment_tenure_rows.include?(at['row']) }
    end

    # Filter assignments and abilities upload fields
    if preview_actions['abilities'].present?
      selected_ability_rows = Array(params[:selected_abilities]).map(&:to_i)
      filtered['abilities'] = preview_actions['abilities'].select { |a| selected_ability_rows.include?(a['row']) }
    end

    if preview_actions['assignment_abilities'].present?
      selected_assignment_ability_rows = Array(params[:selected_assignment_abilities]).map(&:to_i)
      filtered['assignment_abilities'] = preview_actions['assignment_abilities'].select { |aa| selected_assignment_ability_rows.include?(aa['row']) }
    end

    if preview_actions['position_assignments'].present?
      selected_position_assignment_rows = Array(params[:selected_position_assignments]).map(&:to_i)
      filtered['position_assignments'] = preview_actions['position_assignments'].select { |pa| selected_position_assignment_rows.include?(pa['row']) }
    end
    
    filtered
  end
end
