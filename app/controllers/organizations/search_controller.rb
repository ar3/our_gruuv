class Organizations::SearchController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  after_action :verify_authorized

  def show
    authorize :search, :show?
    
    @query = params[:q].to_s.strip
    
    if @query.present?
      search_query = GlobalSearchQuery.new(
        query: @query,
        current_organization: @organization,
        current_person: current_person
      )
      
      @results = search_query.call
    else
      @results = {
        people: [],
        organizations: [],
        observations: [],
        assignments: [],
        abilities: [],
        total_count: 0
      }
    end
  end
end
