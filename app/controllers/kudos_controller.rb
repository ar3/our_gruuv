class KudosController < ApplicationController
  before_action :set_observation
  before_action :authorize_view_permalink

  # Override Pundit's default user method to match the organization namespace pattern
  def pundit_user
    OpenStruct.new(
      user: current_person,
      pundit_organization: nil # KudosController doesn't have organization context
    )
  end

  # Override the rescue behavior to let NotAuthorizedError bubble up for testing
  def user_not_authorized
    raise Pundit::NotAuthorizedError, "You are not authorized to view this observation"
  end

  def show
    # This is the public permalink page that respects privacy settings
    # No authentication required for public observations
  end

  private

  def set_observation
    date = params[:date]
    id = params[:id]
    
    # Parse the permalink_id format: "2025-10-05-142" or "2025-10-05-142-custom-slug"
    permalink_id = "#{date}-#{id}"
    @observation = Observation.find_by_permalink_id(permalink_id)
    
    unless @observation
      raise ActiveRecord::RecordNotFound, "Observation not found"
    end
  end

  def authorize_view_permalink
    # For public observations, no authentication required
    return if @observation.privacy_level == 'public_observation'
    
    # For other privacy levels, require authentication
    unless current_person
      authenticate_person!
      return
    end
    
    # Check if user can view this observation
    unless policy(@observation).view_permalink?
      raise Pundit::NotAuthorizedError, "You are not authorized to view this observation"
    end
  end
end
