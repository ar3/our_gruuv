# frozen_string_literal: true

class Organizations::OgAcademyController < Organizations::OrganizationNamespaceBaseController
  def show
    authorize current_organization, :show?

    @quick_start_people = quick_start_people
    load_quick_start_health_data!
    @academy_progress = OgAcademy::ProgressService.new(
      organization: current_organization,
      company_teammate: current_company_teammate
    )
  end

  def update_start_page
    authorize current_organization, :show?

    allowed = helpers.start_page_options_for_select(current_organization, current_company_teammate).map { |pair| pair.last.to_s }
    value = params.require(:start_page).to_s
    unless allowed.include?(value)
      redirect_to organization_og_academy_path(current_organization), alert: "Invalid start page."
      return
    end

    key = helpers.start_page_preference_key(current_organization)
    UserPreference.for_person(current_person).update_preference(key, value)
    redirect_to helpers.preferred_start_page_path(current_organization, current_company_teammate),
                notice: "Start page updated."
  end

  private

  def quick_start_people
    people = [current_company_teammate]
    if current_company_teammate.has_direct_reports?
      report_ids = EmploymentTenure
        .where(company: current_organization, manager_teammate: current_company_teammate, ended_at: nil)
        .pluck(:teammate_id)
      people += CompanyTeammate.where(id: report_ids).includes(:person).order(:id).to_a
    end
    people.uniq
  end

  def load_quick_start_health_data!
    teammate_ids = @quick_start_people.map(&:id)
    @quick_start_row_data_by_teammate_id = ManagersViewCardDataService.load(
      teammates: @quick_start_people,
      organization: current_organization,
      viewing_teammate: current_company_teammate
    )
    @quick_start_clarity_eh_by_teammate_id = CheckInsHealthEngagementHealthSupport.records_by_teammate_id(
      organization: current_organization,
      teammate_ids: teammate_ids
    )
    @quick_start_goals_eh_by_teammate_id = GoalsHealthEngagementHealthSupport.records_by_teammate_id(
      organization: current_organization,
      teammate_ids: teammate_ids
    )
  end
end
