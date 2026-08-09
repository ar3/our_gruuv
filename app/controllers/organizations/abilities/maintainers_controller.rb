# frozen_string_literal: true

class Organizations::Abilities::MaintainersController < Organizations::OrganizationNamespaceBaseController
  include ObjectMaintainersManagement

  before_action :set_maintainable
  after_action :verify_authorized

  private

  def set_maintainable
    @maintainable = @organization.abilities.find(params[:ability_id])
  end

  def maintainable_show_path
    organization_ability_path(@organization, @maintainable)
  end

  def maintainers_update_path
    organization_ability_maintainers_path(@organization, @maintainable)
  end

  def maintainable_label
    @maintainable.name
  end
end
