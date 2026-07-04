# frozen_string_literal: true

# Start Here "My Employees" widget: direct report counts, fully-healthy count, and averaged Gruuv Health clarity %.
class MyEmployeesDashboardService
  class << self
    def summary(manager_teammate:, organization:)
      new(manager_teammate: manager_teammate, organization: organization).summary
    end
  end

  def initialize(manager_teammate:, organization:)
    @manager_teammate = manager_teammate
    @organization = organization
  end

  def summary
    empty = {
      direct_report_count: 0,
      crystal_clear_count: 0,
      overall_pct: 0.0,
      pill_class: "bg-secondary"
    }
    return empty if @manager_teammate.blank?

    company = @organization.root_company || @organization
    direct_report_ids = EmploymentTenure
      .where(company: company, manager_teammate: @manager_teammate, ended_at: nil)
      .pluck(:teammate_id)
      .uniq

    if direct_report_ids.empty?
      return empty.merge(pill_class: "bg-secondary")
    end

    records_by_teammate_id = EngagementHealth::ClarityMetrics.records_by_teammate_id(
      organization: @organization,
      teammate_ids: direct_report_ids
    )

    crystal_clear = EngagementHealth::ClarityMetrics.crystal_clear_count(
      records_by_teammate_id,
      direct_report_ids
    )

    overall = EngagementHealth::ClarityMetrics.average_healthy_percentage_for_teammates(
      records_by_teammate_id,
      direct_report_ids
    )

    {
      direct_report_count: direct_report_ids.size,
      crystal_clear_count: crystal_clear,
      overall_pct: overall,
      pill_class: pill_class_for_pct(overall)
    }
  end

  private

  def pill_class_for_pct(pct)
    return "bg-secondary" if pct.nil?

    if pct > 80
      "bg-success text-white"
    elsif pct >= 50
      "bg-warning text-dark"
    else
      "bg-danger text-white"
    end
  end
end
