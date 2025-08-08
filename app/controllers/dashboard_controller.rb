class DashboardController < ApplicationController
  before_action :require_login
  
  def index
    @current_person = current_person
    @recent_huddles = current_person.huddles.recent.limit(5)
    @organizations = current_person.available_organizations
  end
  
  private
  
  def require_login
    unless current_person
      redirect_to root_path, alert: 'Please log in to access the dashboard'
    end
  end
end
