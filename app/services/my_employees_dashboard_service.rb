# frozen_string_literal: true

# Start Here "My Employees" widget: direct report counts, crystal-clear count, and averaged check-in clarity %.
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

    caches_by_id = CheckInHealthCache.where(
      teammate_id: direct_report_ids,
      organization_id: @organization.id
    ).index_by(&:teammate_id)

    crystal_clear = direct_report_ids.count do |tid|
      cache = caches_by_id[tid]
      cache && CheckInHealthCompletionRate.teammate_fully_clear_on_check_ins?(cache)
    end

    overall = CheckInHealthCompletionRate.average_completion_rate_per_teammate(
      direct_report_ids,
      @organization.id
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
