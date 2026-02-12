class Organizations::SearchController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  after_action :verify_authorized

  def show
    authorize company, :view_search?
    
    @query = params[:q].to_s.strip
    
    if @query.present?
      search_query = GlobalSearchQuery.new(
        query: @query,
        current_organization: @organization,
        current_teammate: current_company_teammate
      )
      
      @results = search_query.call
    else
      @results = {
        people: [],
        organizations: [],
        observations: [],
        assignments: [],
        abilities: [],
        titles: [],
        total_count: 0
      }
    end
  end
end
