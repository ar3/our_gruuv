# frozen_string_literal: true

class Organizations::Assignments::MaintainersController < Organizations::OrganizationNamespaceBaseController
  include ObjectMaintainersManagement

  before_action :set_maintainable
  after_action :verify_authorized

  private

  def set_maintainable
    @maintainable = @organization.assignments.find(params[:assignment_id])
  end

  def maintainable_show_path
    organization_assignment_path(@organization, @maintainable)
  end

  def maintainers_update_path
    organization_assignment_maintainers_path(@organization, @maintainable)
  end

  def maintainable_label
    @maintainable.title
  end
end
