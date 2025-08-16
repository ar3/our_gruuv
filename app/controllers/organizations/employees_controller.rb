class Organizations::EmployeesController < ApplicationController
  before_action :require_authentication
  before_action :set_organization
  
  def index
    # Get active employees (people with active employment tenures)
    @active_employees = @organization.employees.includes(:employment_tenures)
    
    # Get huddle participants from this organization and all child organizations
    @huddle_participants = @organization.huddle_participants.includes(:employment_tenures)
    
    # Get just huddle participants (non-employees)
    @just_huddle_participants = @organization.just_huddle_participants.includes(:employment_tenures)
  end
  
  private
  
  def set_organization
    @organization = Organization.find(params[:organization_id])
  end
  
  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access organizations.'
    end
  end
end
