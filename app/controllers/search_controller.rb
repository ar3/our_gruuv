class SearchController < ApplicationController
  before_action :authenticate_person!
  after_action :verify_authorized

  def index
    authorize :search, :index?
    
    @query = params[:q].to_s.strip
    @current_organization = current_person.current_organization
    
    if @query.present?
      search_query = GlobalSearchQuery.new(
        query: @query,
        current_organization: @current_organization,
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
