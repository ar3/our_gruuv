class Organizations::SearchController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  after_action :verify_authorized

  def show
    authorize company, :view_search?

    @query = params[:q].to_s.strip
    @ask_og_id = params[:ask_og_id].presence

    if @query.present?
      search_query = GlobalSearchQuery.new(
        query: @query,
        current_organization: @organization,
        current_teammate: current_company_teammate,
        impersonating_teammate: impersonating_teammate
      )

      @results = search_query.call
      SearchQueryLog.record!(
        organization: @organization,
        company_teammate: current_company_teammate,
        query: @query,
        results_count: @results[:total_count]
      )
    else
      @results = {
        people: [],
        organizations: [],
        observations: [],
        assignments: [],
        abilities: [],
        titles: [],
        go_to: [],
        total_count: 0
      }
      @recent_searches = SearchQueryLog.recent_for_teammate(
        company_teammate: current_company_teammate,
        limit: 3
      )
      @recent_ask_ogs = recent_ask_og_threads
    end
  end

  private

  def recent_ask_og_threads
    AskOgResult
      .joins(:og_consultation)
      .where(
        og_consultations: {
          organization_id: @organization.id,
          kind: OgConsultation::KIND_ASK_OG,
          triggered_by_teammate_id: current_company_teammate.id
        }
      )
      .order(created_at: :desc)
      .limit(3)
      .includes(:og_consultation)
  end
end
