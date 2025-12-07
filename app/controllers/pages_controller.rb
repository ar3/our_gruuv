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
    render layout: 'authenticated-horizontal-navigation'
  end
  
  def aspirations_coming_soon
    render layout: 'authenticated-horizontal-navigation'
  end
  
  def observations_coming_soon
    render layout: 'authenticated-horizontal-navigation'
  end
  
  def good_issues_coming_soon
    render layout: 'authenticated-horizontal-navigation'
  end
  
  def diverge_converge_coming_soon
    render layout: 'authenticated-horizontal-navigation'
  end
  
  def team_signals_coming_soon
    render layout: 'authenticated-horizontal-navigation'
  end
  
  def okr3_management_coming_soon
    render layout: 'authenticated-horizontal-navigation'
  end
  
  def hypothesis_management_coming_soon
    render layout: 'authenticated-horizontal-navigation'
  end
  
  def eligibility_reviews_coming_soon
    render layout: 'authenticated-horizontal-navigation'
  end
  
  # Overview pages for Level 2 navigation
  def position_management_overview
    render layout: 'authenticated-horizontal-navigation'
  end
  
  def milestones_overview
    render layout: 'authenticated-horizontal-navigation'
  end
  
  def huddles_overview
    render layout: 'authenticated-horizontal-navigation'
  end
  
  def accountability
    render layout: 'authenticated-horizontal-navigation'
  end
end 