class Organizations::AssignmentSurveysController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  after_action :verify_authorized

  def show
    authorize @organization, :assignment_survey?
    ensure_response_workspace!
    load_take_survey
  end

  def create
    authorize @organization, :assignment_survey?
    if ensure_response_workspace!
      redirect_to survey_take_path, notice: "Ready to give feedback."
    else
      redirect_to organization_assignment_survey_path(@organization),
                  alert: "You do not have any active or required assignments to rate yet."
    end
  end

  def update
    authorize @organization, :assignment_survey?
    apply_response_updates!
    finalize_requested = params[:finalize].present?

    if finalize_requested
      begin
        AssignmentSurveys::Submitter.new(
          teammate: current_company_teammate,
          organization: @organization,
          response_ids: params[:response_ids]
        ).call
        redirect_to survey_take_path,
                    notice: "Assignment feedback submitted. You can update any assignment again anytime."
      rescue AssignmentSurveys::Submitter::Error => e
        ensure_response_workspace!
        load_take_survey
        @form_errors = [ e.message ]
        render :show, status: :unprocessable_entity
      end
    else
      respond_to do |format|
        format.html do
          redirect_to survey_take_path, notice: "Progress saved."
        end
        format.json { render json: { ok: true, saved_at: Time.current.iso8601 } }
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    ensure_response_workspace!
    load_take_survey
    @form_errors = e.record.errors.full_messages
    render :show, status: :unprocessable_entity
  end

  def destroy
    authorize @organization, :assignment_survey?
    scope = current_company_teammate.assignment_survey_responses
      .in_progress
      .where(organization: @organization)

    if scope.exists?
      scope.destroy_all
      redirect_to organization_assignment_survey_path(@organization), notice: "Unsaved progress cleared."
    else
      redirect_to organization_assignment_survey_path(@organization), alert: "Nothing to clear."
    end
  end

  def results
    authorize @organization, :assignment_survey_results?
    @assignment_sort = AssignmentSurveys::Results.normalize_assignment_sort(params[:sort])
    @maintained_assignment_ids = ObjectMaintainer.maintained_assignment_ids_for(current_company_teammate)
    @results = AssignmentSurveys::Results.new(
      organization: @organization,
      teammates: visible_teammates,
      maintained_assignment_ids: @maintained_assignment_ids,
      assignment_sort: @assignment_sort
    )
  end

  def teammate_responses
    authorize @organization, :assignment_survey_results?
    @teammate = visible_teammates.find(params[:teammate_id])
    @submitted_responses = @teammate.assignment_survey_responses
      .where(organization: @organization)
      .submitted
      .includes(:assignment)
      .order(submitted_at: :desc, id: :desc)
    @in_progress_responses = @teammate.assignment_survey_responses
      .where(organization: @organization)
      .in_progress
      .includes(:assignment)
      .order(:snapshot_title)
  end

  def export
    authorize @organization, :assignment_survey_results?
    csv = AssignmentSurveys::CsvBuilder.new(
      organization: @organization,
      teammates: visible_teammates
    ).call
    filename = "assignment_experience_survey_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    send_data csv, filename: filename, type: "text/csv", disposition: "attachment"
  end

  private

  def require_authentication
    redirect_to root_path, alert: "Please log in to access this page." unless current_company_teammate
  end

  def ensure_response_workspace!
    workspace = AssignmentSurveys::ResponseWorkspace.new(
      organization: @organization,
      teammate: current_company_teammate,
      assignment_ids: params[:assignment_id].presence
    )
    responses = workspace.call
    responses.any?
  end

  def load_take_survey
    @focus_assignment_id = params[:assignment_id].presence&.to_i
    @workspace = AssignmentSurveys::ResponseWorkspace.new(
      organization: @organization,
      teammate: current_company_teammate,
      assignment_ids: params[:assignment_id].presence
    )
    @in_progress_responses = @workspace.in_progress_responses.to_a
    @single_assignment_focus = @focus_assignment_id.present?
    @submitted_responses = current_company_teammate.assignment_survey_responses
      .where(organization: @organization)
      .submitted
      .latest_submitted_first
      .includes(:assignment)
      .limit(20)

    assignment_rows = AssignmentSurveys::ResponseWorkspace.assignment_rows_for(
      organization: @organization,
      teammate: current_company_teammate
    )
    @survey_assignments = assignment_rows.map(&:first)
    @due_statuses = AssignmentSurveys::DueStatus.for_teammate(
      teammate: current_company_teammate,
      assignments: @survey_assignments
    ).index_by { |status| status.assignment.id }
    @due_count = @due_statuses.values.count(&:due?)
  end

  def apply_response_updates!
    response_params = params.fetch(:assignment_survey_responses, ActionController::Parameters.new).permit!
    return if response_params.blank?

    response_params.each do |_index, attrs|
      response = current_company_teammate.assignment_survey_responses.in_progress.find(attrs[:id])
      response.update!(attrs.except(:id).permit(
        :understandable_rating,
        :possible_rating,
        :relevant_rating,
        :personal_alignment,
        :comment
      ))
    end
  end

  def survey_take_path
    options = {}
    options[:assignment_id] = params[:assignment_id] if params[:assignment_id].present?
    if params[:assignment_id].present?
      options[:anchor] = "assignment-survey-response-#{params[:assignment_id]}"
    end
    organization_assignment_survey_path(@organization, **options)
  end

  def visible_teammates
    @visible_teammates ||= people_results_visible_teammates
  end

  def people_results_visible_teammates
    if policy(@organization).manage_employment?
      @organization.company_teammates.employed
    else
      CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).employed
    end
  end
end
