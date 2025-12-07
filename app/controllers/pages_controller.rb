class PagesController < ApplicationController
  layout false, only: [:home]
  
  def home
    if current_person
      # If logged in but no current organization, redirect to organization switcher
      if current_organization.nil?
        redirect_to switch_organizations_path
        return
      end
      
      # If logged in with current organization, redirect to organization dashboard
      redirect_to dashboard_organization_path(current_organization)
      return
    end
    
    # If not logged in, show the marketing home page
  end
  
  # Coming Soon placeholder pages
  def seats_coming_soon
    render layout: determine_layout
  end
  
  def aspirations_coming_soon
    render layout: determine_layout
  end
  
  def observations_coming_soon
    render layout: determine_layout
  end
  
  def good_issues_coming_soon
    render layout: determine_layout
  end
  
  def diverge_converge_coming_soon
    render layout: determine_layout
  end
  
  def team_signals_coming_soon
    render layout: determine_layout
  end
  
  def okr3_management_coming_soon
    render layout: determine_layout
  end
  
  def hypothesis_management_coming_soon
    render layout: determine_layout
  end
  
  def eligibility_reviews_coming_soon
    render layout: determine_layout
  end
  
  # Overview pages for Level 2 navigation
  def position_management_overview
    render layout: determine_layout
  end
  
  def milestones_overview
    render layout: determine_layout
  end
  
  def huddles_overview
    render layout: determine_layout
  end
  
  def accountability
    render layout: determine_layout
  end
end 