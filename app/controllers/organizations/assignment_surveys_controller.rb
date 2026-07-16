class Organizations::AssignmentSurveysController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  after_action :verify_authorized

  def show
    authorize @organization, :assignment_survey?
    load_take_survey
  end

  def create
    authorize @organization, :assignment_survey?
    submission = AssignmentSurveys::DraftBuilder.new(
      organization: @organization,
      teammate: current_company_teammate
    ).call

    if submission
      redirect_to organization_assignment_survey_path(@organization), notice: "Your survey draft is ready."
    else
      redirect_to organization_assignment_survey_path(@organization),
                  alert: "You do not have any active or required assignments to rate yet."
    end
  end

  def update
    authorize @organization, :assignment_survey?
    @draft = current_company_teammate.assignment_survey_submissions
      .where(organization: @organization)
      .draft
      .includes(:responses)
      .first!

    @draft.assign_attributes(submission_params)
    finalize_requested = params[:finalize].present?

    if @draft.save
      if finalize_requested
        @draft.finalize!
        redirect_to organization_assignment_survey_path(@organization),
                    notice: "Your assignment experience survey was finalized."
      else
        respond_to do |format|
          format.html do
            redirect_to organization_assignment_survey_path(@organization), notice: "Draft saved."
          end
          format.json { render json: { ok: true, saved_at: Time.current.iso8601 } }
        end
      end
    else
      respond_to do |format|
        format.html do
          load_take_survey
          render :show, status: :unprocessable_entity
        end
        format.json { render json: { ok: false, errors: @draft.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  rescue ActiveRecord::RecordInvalid
    @draft.reload
    load_take_survey
    @draft.errors.add(:base, "Every assignment needs all three ratings before finalizing")
    render :show, status: :unprocessable_entity
  end

  def results
    authorize @organization, :assignment_survey_results?
    @results = AssignmentSurveys::Results.new(organization: @organization, teammates: visible_teammates)
  end

  def submission
    authorize @organization, :assignment_survey_results?
    @submission = AssignmentSurveySubmission
      .where(organization: @organization, teammate_id: visible_teammates.select(:id))
      .includes(:company_teammate, :responses)
      .find(params[:submission_id])
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

  def load_take_survey
    @draft ||= current_company_teammate.assignment_survey_submissions
      .where(organization: @organization)
      .draft
      .includes(:responses)
      .first
    @finalized_submissions = current_company_teammate.assignment_survey_submissions
      .where(organization: @organization)
      .finalized
      .latest_first
  end

  def visible_teammates
    @visible_teammates ||= if policy(@organization).manage_employment?
      @organization.company_teammates.employed
    else
      CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).employed
    end
  end

  def submission_params
    params.fetch(:assignment_survey_submission, ActionController::Parameters.new).permit(
      responses_attributes: [
        :id,
        :understandable_rating,
        :possible_rating,
        :relevant_rating,
        :comment
      ]
    )
  end
end
