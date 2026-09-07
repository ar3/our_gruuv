# frozen_string_literal: true

class Organizations::TeamsHealthController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  after_action :verify_authorized

  def index
    authorize @organization, :teams_health?
    @summary = TeamsHealth::Summary.new(organization: @organization).call
  end

  private

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to access this page."
  end
end
