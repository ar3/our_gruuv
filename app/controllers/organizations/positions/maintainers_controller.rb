# frozen_string_literal: true

class Organizations::Positions::MaintainersController < Organizations::OrganizationNamespaceBaseController
  include ObjectMaintainersManagement

  before_action :set_maintainable
  after_action :verify_authorized

  private

  def set_maintainable
    @maintainable = Position.for_company(@organization).find(params[:position_id])
  end

  def maintainable_show_path
    organization_position_path(@organization, @maintainable)
  end

  def maintainers_update_path
    organization_position_maintainers_path(@organization, @maintainable)
  end

  def maintainable_label
    @maintainable.display_name
  end
end
