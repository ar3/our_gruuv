# frozen_string_literal: true

class Organizations::DepartmentsHealthController < Organizations::OrganizationNamespaceBaseController
  def index
    authorize @organization, :departments_health?
    @overview = DepartmentsHealth::ExpectationAlignmentOverview.call(organization: @organization)
  end

  def refresh_all
    authorize @organization, :departments_health?

    overview = DepartmentsHealth::ExpectationAlignmentOverview.call(organization: @organization)
    overview.title_ids.each { |id| TitleExpectationAlignmentScoreRefreshJob.perform_later(id) }
    overview.position_ids.each { |id| PositionExpectationAlignmentScoreRefreshJob.perform_later(id) }
    overview.assignment_ids.each { |id| AssignmentExpectationAlignmentScoreRefreshJob.perform_later(id) }

    total = overview.title_ids.size + overview.position_ids.size + overview.assignment_ids.size
    redirect_to organization_departments_health_path(@organization),
                notice: "Queued Expectation Alignment Score refresh for #{total} #{'record'.pluralize(total)}. Refresh this page in a moment."
  end
end
