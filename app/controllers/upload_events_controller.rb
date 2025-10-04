class UploadEventsController < Organizations::OrganizationNamespaceBaseController
  layout 'authenticated-v2-0'
  before_action :require_login
  before_action :set_upload_event, only: [:show, :destroy, :process_upload]
  before_action :authorize_upload_events, only: [:index, :new, :create, :process_upload]

  def index
    @upload_events = policy_scope(UploadEvent)
                     .includes(:creator, :initiator)
                     .order(created_at: :desc)
    
    # Spotlight statistics
    @spotlight_stats = {
      total_uploads: @upload_events.count,
      completed_uploads: @upload_events.completed.count,
      ready_for_preview: @upload_events.preview.count,
      failed_uploads: @upload_events.failed.count,
      processing_uploads: @upload_events.processing.count,
      recent_uploads: @upload_events.where('created_at > ?', 7.days.ago).count,
      assignment_checkins: @upload_events.where(type: ['UploadAssignmentCheckins', 'UploadEvent::UploadAssignmentCheckins']).count,
      employee_uploads: @upload_events.where(type: ['UploadEmployees', 'UploadEvent::UploadEmployees']).count
    }
  end

  def show
    # Show page displays upload details, preview actions, and results
  end

  def new
    type_param = params.dig(:upload_event, :type)
    
    if type_param.blank?
      redirect_to organization_upload_events_path(current_organization), alert: 'Please select an upload type from the dropdown.'
      return
    end
    
    begin
      @upload_event = type_param.constantize.new
    rescue NameError
      redirect_to organization_upload_events_path(current_organization), alert: 'Invalid upload type selected.'
      return
    end
  end

  def create
    # Validate required parameters
    unless params[:upload_event].present?
      redirect_to organization_upload_events_path(current_organization), alert: 'Type can\'t be blank'
      return
    end

    type_param = params[:upload_event][:type]
    unless type_param.present?
      redirect_to organization_upload_events_path(current_organization), alert: 'Type can\'t be blank'
      return
    end

    unless type_param.in?(['UploadEvent::UploadAssignmentCheckins', 'UploadEvent::UploadEmployees'])
      redirect_to organization_upload_events_path(current_organization), alert: 'Type is not included in the list'
      return
    end

    begin
      @upload_event = type_param.constantize.new
    rescue NameError
      redirect_to organization_upload_events_path(current_organization), alert: 'Invalid upload type selected.'
      return
    end

    @upload_event.organization = current_organization
    @upload_event.creator = current_person
    @upload_event.initiator = current_person

    # Handle file upload
    if params[:upload_event][:file].present?
      file = params[:upload_event][:file]
      
      # Validate file type using the subclass method
      unless @upload_event.validate_file_type(file)
        redirect_to organization_upload_events_path(current_organization), alert: "Please upload a valid #{@upload_event.file_extension.upcase} file."
        return
      end
      
      # Save the filename and read file content
      @upload_event.filename = file.original_filename
      @upload_event.file_content = @upload_event.process_file_content_for_storage(file)
    else
      @upload_event.errors.add(:file, 'is required')
      render :new, status: :unprocessable_entity
      return
    end

    if @upload_event.save
      # Parse the uploaded file to generate preview actions
      if @upload_event.process_file_for_preview
        redirect_to organization_upload_event_path(current_organization, @upload_event), notice: 'Upload created successfully. Please review the preview before processing.'
      else
        @upload_event.destroy
        redirect_to organization_upload_events_path(current_organization), alert: @upload_event.parse_error_message
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    if @upload_event.can_destroy?
      @upload_event.destroy
      redirect_to organization_upload_events_path(current_organization), notice: 'Upload deleted successfully.'
    else
      redirect_to organization_upload_event_path(current_organization, @upload_event), alert: 'Cannot delete this upload.'
    end
  end

  def process_upload
    unless @upload_event.can_process?
      redirect_to organization_upload_event_path(current_organization, @upload_event), alert: 'This upload cannot be processed.'
      return
    end

    # Filter preview actions based on selected items
    filtered_preview_actions = filter_preview_actions_by_selection(@upload_event.preview_actions, params)
    
    # Update the upload event with filtered actions
    @upload_event.update!(preview_actions: filtered_preview_actions)

    # Process the upload inline and get the result
    result = EmploymentDataUploadProcessorJob.perform_and_get_result(@upload_event.id, current_organization.id)
    
    if result
      redirect_to organization_upload_event_path(current_organization, @upload_event), notice: 'Upload processed successfully!'
    else
      redirect_to organization_upload_event_path(current_organization, @upload_event), alert: 'Upload processing failed. Please check the logs for details.'
    end
  end

  private

  def require_login
    unless current_person
      redirect_to root_path, alert: 'Please log in to access this page'
    end
  end

  def set_upload_event
    @upload_event = organization.upload_events.find(params[:id])
  end

  def upload_event_params
    params.require(:upload_event).permit()
  end

  def authorize_upload_events
    authorize UploadEvent
  end

  def filter_preview_actions_by_selection(preview_actions, params)
    filtered = {}
    
    # Filter people
    if preview_actions['people'].present?
      selected_people_rows = Array(params[:selected_people]).map(&:to_i)
      filtered['people'] = preview_actions['people'].select { |p| selected_people_rows.include?(p['row']) }
    end
    
    # Filter assignments
    if preview_actions['assignments'].present?
      selected_assignment_rows = Array(params[:selected_assignments]).map(&:to_i)
      filtered['assignments'] = preview_actions['assignments'].select { |a| selected_assignment_rows.include?(a['row']) }
    end
    
    # Filter assignment tenures
    if preview_actions['assignment_tenures'].present?
      selected_tenure_rows = Array(params[:selected_tenures]).map(&:to_i)
      filtered['assignment_tenures'] = preview_actions['assignment_tenures'].select { |t| selected_tenure_rows.include?(t['row']) }
    end
    
    # Filter assignment check-ins
    if preview_actions['assignment_check_ins'].present?
      selected_check_in_rows = Array(params[:selected_check_ins]).map(&:to_i)
      filtered['assignment_check_ins'] = preview_actions['assignment_check_ins'].select { |c| selected_check_in_rows.include?(c['row']) }
    end
    
    # Filter external references
    if preview_actions['external_references'].present?
      selected_ref_rows = Array(params[:selected_external_refs]).map(&:to_i)
      filtered['external_references'] = preview_actions['external_references'].select { |r| selected_ref_rows.include?(r['row']) }
    end
    
    filtered
  end
end
