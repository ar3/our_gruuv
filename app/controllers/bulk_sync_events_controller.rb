class BulkSyncEventsController < Organizations::OrganizationNamespaceBaseController
  before_action :require_login
  before_action :set_bulk_sync_event, only: [:show, :destroy, :process_sync]
  before_action :authorize_bulk_sync_events, only: [:new, :create]

  def index
    authorize company, :view_bulk_sync_events?
    @bulk_sync_events = policy_scope(BulkSyncEvent)
                     .includes(:creator, :initiator)
                     .order(created_at: :desc)
    
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
      refresh_slack: @bulk_sync_events.where(type: 'BulkSyncEvent::RefreshSlackSync').count
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
    Rails.logger.info "❌❌❌ BulkSyncEventsController: Processing sync for bulk_sync_event #{@bulk_sync_event.id} (type: #{@bulk_sync_event.type})"
    
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
      when 'BulkSyncEvent::RefreshNamesSync'
        Rails.logger.debug "❌❌❌ BulkSyncEventsController: Using RefreshNamesSyncProcessorJob"
        RefreshNamesSyncProcessorJob.perform_and_get_result(@bulk_sync_event.id, current_organization.id)
      when 'BulkSyncEvent::RefreshSlackSync'
        Rails.logger.debug "❌❌❌ BulkSyncEventsController: Using RefreshSlackSyncProcessorJob"
        RefreshSlackSyncProcessorJob.perform_and_get_result(@bulk_sync_event.id, current_organization.id)
      else
        Rails.logger.warn "❌❌❌ BulkSyncEventsController: Unknown type #{@bulk_sync_event.type}, using EmploymentDataUploadProcessorJob"
        EmploymentDataUploadProcessorJob.perform_and_get_result(@bulk_sync_event.id, current_organization.id)
      end
      
      if result
        Rails.logger.info "❌❌❌ BulkSyncEventsController: Sync processed successfully for bulk_sync_event #{@bulk_sync_event.id}"
        redirect_to organization_bulk_sync_event_path(current_organization, @bulk_sync_event), notice: 'Sync processed successfully!'
      else
        Rails.logger.error "❌❌❌ BulkSyncEventsController: Sync processing returned false for bulk_sync_event #{@bulk_sync_event.id}"
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
    
    if preview_actions['position_types'].present?
      selected_position_type_rows = Array(params[:selected_position_types]).map(&:to_i)
      filtered['position_types'] = preview_actions['position_types'].select { |pt| selected_position_type_rows.include?(pt['row']) }
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
