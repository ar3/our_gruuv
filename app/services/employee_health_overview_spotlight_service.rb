# frozen_string_literal: true

require "ostruct"

# Employee Health Overview spotlight: check-ins, goals, and observations health
# compact stats scoped to a manager's direct reports (My Employees view).
class EmployeeHealthOverviewSpotlightService
  attr_reader :organization, :current_person, :current_company_teammate, :manage_employment, :manager_teammate_id

  def initialize(organization:, current_person:, current_company_teammate:, manage_employment:, manager_teammate_id:)
    @organization = organization
    @current_person = current_person
    @current_company_teammate = current_company_teammate
    @manage_employment = manage_employment
    @manager_teammate_id = manager_teammate_id
  end

  def stats
    filter = manager_filter_value
    {
      manager_filter: filter,
      check_ins: check_ins_section(filter),
      goals: goals_section(filter),
      observations: observations_section(filter)
    }
  end

  private

  def manager_filter_value
    mid = Array(manager_teammate_id).first
    return goals_filtering.default_manager_filter_value if mid.blank?

    if current_company_teammate && mid.to_i == current_company_teammate.id
      "my_direct_employees"
    else
      "CompanyTeammate_#{mid}"
    end
  end

  def goals_filtering
    @goals_filtering ||= GoalsHealthSpotlightService.new(
      organization: organization,
      current_person: current_person,
      current_company_teammate: current_company_teammate,
      manage_employment: manage_employment
    )
  end

  def organization_policy
    @organization_policy ||= begin
      imp = nil # controller impersonation not available in service; manage_employment covers admin paths
      puser = OpenStruct.new(user: current_company_teammate, impersonating_teammate: imp)
      OrganizationPolicy.new(puser, organization)
    end
  end

  def check_ins_section(filter)
    return nil unless organization_policy.check_ins_health?

    {
      stats: CheckInsHealthSpotlightService.new(
        organization: organization,
        current_person: current_person,
        current_company_teammate: current_company_teammate,
        manage_employment: manage_employment
      ).compact_spotlight_stats(filter)
    }
  end

  def goals_section(filter)
    return nil unless organization_policy.goals_health?

    {
      stats: goals_filtering.rows_and_spotlight_for(filter).fetch(:spotlight_stats)
    }
  end

  def observations_section(filter)
    return nil unless organization_policy.observations_health?

    {
      stats: ObservationsHealthSpotlightService.new(
        organization: organization,
        current_person: current_person,
        current_company_teammate: current_company_teammate,
        manage_employment: manage_employment
      ).compact_spotlight_stats(filter)
    }
  end
end
