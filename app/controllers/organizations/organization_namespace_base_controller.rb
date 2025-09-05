class Organizations::OrganizationNamespaceBaseController < ApplicationController
  before_action :set_organization, unless: :skip_organization_setup?
  helper_method :organization

  # Override Pundit's default user method to include organization context
  def pundit_user
    OpenStruct.new(
      user: current_person,
      pundit_organization: organization
    )
  end

  protected

  def set_organization
    @organization = organization
  end

  def organization
    @organization ||= Organization.find(params[:organization_id] || params[:id])
  end

  # Override this method in child controllers to skip organization setup for certain actions
  def skip_organization_setup?
    false
  end
end
