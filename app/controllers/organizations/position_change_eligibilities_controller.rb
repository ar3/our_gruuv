# frozen_string_literal: true

module Organizations
  class PositionChangeEligibilitiesController < Organizations::OrganizationNamespaceBaseController
    before_action :authenticate_person!
    before_action :set_position
    before_action :set_teammate
    before_action :authorize_access!

    def run
      if @teammate.latest_position_change_eligibility_consultation_for(@position)&.in_flight?
        redirect_to eligibility_path, alert: 'A Position-Change Eligibility consultation is already running.'
        return
      end

      entry = OgConsultations::Kinds.fetch(OgConsultation::KIND_POSITION_CHANGE_ELIGIBILITY)
      builder = Maap::PositionChangeEligibilityPayloadBuilder.new(
        teammate: @teammate,
        position: @position,
        organization: organization
      )
      built = builder.call

      consultation = OgConsultation.create!(
        kind: entry.kind,
        subject: @teammate,
        organization_id: organization.id,
        triggered_by_teammate: current_company_teammate,
        status: 'pending',
        billable: entry.billable,
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
        units_total: built.units_total,
        units_completed: 0
      )
      result = entry.result_class.create!(
        og_consultation: consultation,
        position: @position,
        change_type: built.change_type
      )
      consultation.update!(result: result)
      entry.job_class.perform_later(@teammate.id, @position.id, organization.id, consultation.id)

      redirect_to eligibility_path(consultation_id: consultation.id),
                  notice: 'Consult OG — Position-Change Eligibility started. This page will update when processing finishes.'
    end

    def status
      run = find_consultation
      if run.nil?
        return render json: { status: 'none', id: nil, elapsed_seconds: 0, stale: false, slow: false }
      end

      render json: OgConsultations::StatusPayload.for_consultation(run, error_message: run.error_message)
    end

    private

    def set_position
      @position = Position.find_by_param(params[:id])
    end

    def set_teammate
      teammate_id = params[:teammate_id].presence || current_company_teammate&.id
      @teammate = CompanyTeammate.find(teammate_id)
    end

    def authorize_access!
      authorize :eligibility_requirement, :show?
      return if teammate_allowed?

      flash[:alert] = "You don't have access to that teammate."
      redirect_to organization_eligibility_requirements_path(organization)
    end

    def teammate_allowed?
      return false unless @teammate
      return true if current_company_teammate && @teammate.id == current_company_teammate.id

      selectable_teammates.any? { |allowed| allowed.id == @teammate.id }
    end

    def selectable_teammates
      return [] unless current_person

      teammates = []
      teammates << current_company_teammate if current_company_teammate

      if CompanyTeammate.can_manage_employment_in_hierarchy?(current_person, organization)
        teammates.concat(
          CompanyTeammate.for_organization_hierarchy(organization)
                  .where(last_terminated_at: nil)
                  .includes(:person)
        )
      else
        reports = EmployeeHierarchyQuery.new(person: current_person, organization: organization).call
        report_person_ids = reports.map { |report| report[:person_id] }
        org_ids = organization.company? ? organization.self_and_descendants.map(&:id) : [organization.id]

        teammates.concat(
          CompanyTeammate.where(organization_id: org_ids, person_id: report_person_ids, last_terminated_at: nil)
                  .includes(:person)
        )
      end

      teammates.compact.uniq { |teammate| teammate.id }
    end

    def find_consultation
      id = params[:consultation_id].presence
      scope = @teammate.position_change_eligibility_consultations_for(@position)
      id.present? ? scope.find_by(id: id) : scope.first
    end

    def eligibility_path(extra = {})
      organization_eligibility_requirement_path(
        organization,
        @position,
        { teammate_id: @teammate.id }.merge(extra)
      )
    end
  end
end
