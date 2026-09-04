# frozen_string_literal: true

class Organizations::AssignmentsHealthController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  after_action :verify_authorized

  def index
    authorize @organization, :assignments_health?
    @overview = overview_service.call
  end

  def refresh
    authorize @organization, :assignments_health?

    assignment = find_unarchived_assignment(params[:assignment_id])
    unless assignment
      redirect_back fallback_location: organization_assignments_health_path(@organization),
                    alert: "Could not refresh: assignment not found."
      return
    end

    AssignmentExpectationAlignmentScoreRefreshJob.perform_later(assignment.id)
    redirect_back fallback_location: organization_assignments_health_path(@organization),
                  notice: "Expectation Alignment Score refresh queued for #{assignment.title}."
  end

  def refresh_missing_and_stale
    authorize @organization, :assignments_health?

    ids = overview_service.call.refreshable_assignment_ids
    ids.each { |assignment_id| AssignmentExpectationAlignmentScoreRefreshJob.perform_later(assignment_id) }

    redirect_to organization_assignments_health_path(@organization),
                notice: refresh_notice(ids.size)
  end

  private

  def overview_service
    @overview_service ||= AssignmentsHealth::ExpectationAlignmentOverview.new(organization: @organization)
  end

  def find_unarchived_assignment(assignment_id)
    Assignment.unarchived.for_company(@organization).find_by(id: assignment_id)
  end

  def refresh_notice(count)
    if count.zero?
      "No missing or stale Expectation Alignment Scores to refresh."
    else
      "Expectation Alignment Score refresh queued for #{count} assignment#{'s' if count != 1}."
    end
  end

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to access this page."
  end
end
