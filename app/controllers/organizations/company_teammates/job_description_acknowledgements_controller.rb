# frozen_string_literal: true

class Organizations::CompanyTeammates::JobDescriptionAcknowledgementsController < Organizations::OrganizationNamespaceBaseController
  include Organizations::AssignsViewableTeammates

  before_action :authenticate_person!
  before_action :set_teammate
  after_action :verify_authorized

  def index
    authorize @teammate, :view_job_description_acknowledgements?, policy_class: CompanyTeammatePolicy
    load_page
    @acknowledgement = JobDescriptionAcknowledgement.new
  end

  def show
    authorize @teammate, :view_job_description_acknowledgements?, policy_class: CompanyTeammatePolicy
    assign_viewable_teammates_context!(selected_teammate: @teammate)
    @acknowledgement = @teammate.job_description_acknowledgements.find(params[:id])
  end

  def create
    authorize @teammate, :create_job_description_acknowledgement?, policy_class: CompanyTeammatePolicy
    document = JobDescriptionAcknowledgements::Document.call(teammate: @teammate, organization: organization)
    signed_at = Time.current
    typed_name = acknowledgement_params[:typed_name]
    @acknowledgement = @teammate.job_description_acknowledgements.build(
      organization: organization,
      employment_tenure: document.employment_tenure,
      position: document.position,
      typed_name: typed_name,
      signed_at: signed_at,
      snapshot: document.snapshot,
      request_info: build_request_info(signed_at: signed_at),
      document_html: render_to_string(
        partial: "organizations/company_teammates/job_description_acknowledgements/document",
        locals: {
          snapshot: document.snapshot,
          organization: organization,
          teammate: @teammate,
          typed_name: typed_name,
          signed_at: signed_at
        }
      )
    )

    if @acknowledgement.save
      redirect_to organization_company_teammate_job_description_acknowledgement_path(organization, @teammate, @acknowledgement),
                  notice: "Job description signed."
    else
      load_page
      render :index, status: :unprocessable_entity
    end
  end

  private

  def set_teammate
    @teammate = find_organization_teammate!(params[:company_teammate_id], scope: organization.teammates.includes(:person))
  end

  def load_page
    assign_viewable_teammates_context!(selected_teammate: @teammate)
    @document = JobDescriptionAcknowledgements::Document.call(teammate: @teammate, organization: organization)
    @acknowledgements = @teammate.job_description_acknowledgements.order(signed_at: :desc)
    @compliance_status = JobDescriptionAcknowledgements::ComplianceStatus.call(
      teammate: @teammate,
      organization: organization,
      acknowledgements: @acknowledgements
    )
  end

  def acknowledgement_params
    params.require(:job_description_acknowledgement).permit(:typed_name)
  end

  def build_request_info(signed_at:)
    {
      "ip_address" => request.remote_ip.to_s,
      "user_agent" => request.user_agent.to_s,
      "timestamp" => signed_at.iso8601,
      "session_id" => session.id.to_s,
      "request_id" => request.request_id.to_s,
      "request_source" => "true_jd_signed_page"
    }
  end
end
