# frozen_string_literal: true

class Organizations::CompanyTeammates::PossibleObservationSlackSearchRunsController < Organizations::OrganizationNamespaceBaseController
  include Organizations::AssignsViewableTeammates

  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_one_on_one_link
  before_action :authorize_ogos!
  before_action :assign_viewable_teammates_context
  before_action :set_search, only: :show
  after_action :verify_authorized

  def index
    @searches = PossibleObservationSlackSearch
                .for_subject(@teammate)
                .where(organization: organization)
                .recent_first
                .includes(creator_company_teammate: :person)
                .limit(50)
    @run_stats_by_id = @searches.index_with do |search|
      PossibleObservationSlackSearches::RunStats.call(search: search)
    end
  end

  def show
    @stats = PossibleObservationSlackSearches::RunStats.call(search: @search)
    @moments = PossibleObservationSlackSearches::VisibleSlackPossibleObservations.call(
      subject: @teammate,
      viewer: current_company_teammate,
      organization: organization,
      search_id: @search.id
    )
  end

  private

  def set_teammate
    # Member routes: /company_teammates/:id/ogos/slack_search_runs...
    @teammate = find_organization_teammate!(params[:id])
  end

  def set_one_on_one_link
    @one_on_one_link = @teammate&.one_on_one_link || OneOnOneLink.new(teammate: @teammate)
  end

  def authorize_ogos!
    authorize @one_on_one_link, :ogos?
  end

  def assign_viewable_teammates_context
    assign_viewable_teammates_context!(selected_teammate: @teammate) if @teammate
  end

  def set_search
    @search = PossibleObservationSlackSearch
              .for_subject(@teammate)
              .where(organization: organization)
              .find(params[:search_id])
  end
end

