class Organizations::OrganizationNamespaceBaseController < ApplicationController
  helper_method :organization

  # Override Pundit's default user method to include organization context
  def pundit_user
    OpenStruct.new(
      user: current_person,
      pundit_organization: organization
    )
  end

  protected

  def organization
    @organization ||= Organization.find(params[:organization_id] || params[:id])
  end
end
