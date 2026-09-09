# frozen_string_literal: true

class Organizations::PositionsHealthController < Organizations::OrganizationNamespaceBaseController
  def index
    authorize @organization, :positions_health?
    @overview = PositionsHealth::TitleExpectationAlignmentOverview.call(organization: @organization)
  end

  def refresh_all
    authorize @organization, :positions_health?

    title_ids = @organization.titles.unarchived.pluck(:id)
    title_ids.each { |id| TitleExpectationAlignmentScoreRefreshJob.perform_later(id) }

    redirect_to organization_positions_health_path(@organization),
                notice: "Queued Title Expectation Alignment Score refresh for #{title_ids.size} #{'title'.pluralize(title_ids.size)}. Refresh this page in a moment."
  end
end
