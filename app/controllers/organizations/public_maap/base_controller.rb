class Organizations::PublicMaap::BaseController < ApplicationController
  layout 'public_maap'
  
  before_action :set_organization
  
  protected
  
  def set_organization
    org_param = params[:organization_id] || params[:id]
    @organization = Organization.find_by_param(org_param)
    
    unless @organization
      raise ActiveRecord::RecordNotFound, "Organization not found"
    end
  end
end


