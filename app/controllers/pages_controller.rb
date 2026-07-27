class PagesController < ApplicationController
  layout :marketing_or_app_layout

  MARKETING_ACTIONS = %w[
    home
    solutions flow_state pricing start_free
    about
  ].freeze

  def home
    redirect_logged_in_from_marketing! && return
  end

  def solutions; end
  def flow_state; end
  def pricing; end
  def start_free; end

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

  def about; end

  def new_us
    render layout: 'application'
  end

  def close_tab
    @return_text = params[:return_text] || 'previous page'
    render layout: 'overlay'
  end

  private

  def marketing_or_app_layout
    return 'marketing' if MARKETING_ACTIONS.include?(action_name)

    determine_layout
  end

  def redirect_logged_in_from_marketing!
    return false unless current_person

    if current_organization.nil?
      redirect_to switch_organizations_path
    else
      redirect_to helpers.preferred_start_page_path(current_organization, current_company_teammate)
    end
    true
  end
end
