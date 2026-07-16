# frozen_string_literal: true

class Organizations::CompanyTeammates::PossibleObservationSlackSearchesController < Organizations::OrganizationNamespaceBaseController
  include Organizations::AssignsViewableTeammates

  before_action :authenticate_person!
  before_action :set_subject_teammate
  before_action :set_one_on_one_link
  before_action :assign_viewable_teammates_context
  before_action :set_search, only: %i[show destroy]
  after_action :verify_authorized

  def create
    authorize PossibleObservationSlackSearch.new(
      organization: organization,
      creator_company_teammate: current_company_teammate,
      subject_company_teammate: @teammate
    )

    unless current_company_teammate&.has_slack_search_identity?
      redirect_to ogos_source_from_slack_organization_company_teammate_path(organization, @teammate),
                  alert: "Connect Slack (search) before running a search."
      return
    end

    window_days = permitted_window_days
    search = PossibleObservationSlackSearch.new(
      organization: organization,
      creator_company_teammate: current_company_teammate,
      subject_company_teammate: @teammate,
      window_days: window_days,
      display_name: default_display_name(window_days),
      search_status: "pending"
    )

    if search.save
      PossibleObservationSlackSearches::RunSearchService.call(search: search)
      redirect_to organization_company_teammate_possible_observation_slack_search_path(
        organization,
        @teammate,
        search
      ), notice: search_notice(search)
    else
      redirect_to ogos_source_from_slack_organization_company_teammate_path(organization, @teammate),
                  alert: search.errors.full_messages.to_sentence
    end
  end

  def show
    authorize @search
    @casual_name = @teammate.person.casual_name
    @active_tab = :source_from_slack
    @messages = @search.raw_messages
  end

  def destroy
    authorize @search
    @search.destroy!
    redirect_to ogos_source_from_slack_organization_company_teammate_path(organization, @teammate),
                notice: "Slack search deleted."
  end

  private

  def set_subject_teammate
    @teammate = find_organization_teammate!(params[:company_teammate_id])
  end

  def set_one_on_one_link
    @one_on_one_link = @teammate&.one_on_one_link || OneOnOneLink.new(teammate: @teammate)
    authorize @one_on_one_link, :ogos?
  end

  def assign_viewable_teammates_context
    return unless @teammate

    assign_viewable_teammates_context!(selected_teammate: @teammate)
  end

  def set_search
    @search = PossibleObservationSlackSearch
              .where(organization: organization, subject_company_teammate: @teammate)
              .find(params[:id])
  end

  def permitted_window_days
    days = params.dig(:possible_observation_slack_search, :window_days).to_i
    return days if PossibleObservationSlackSearch::ALLOWED_WINDOW_DAYS.include?(days)

    PossibleObservationSlackSearch::DEFAULT_WINDOW_DAYS
  end

  def default_display_name(window_days)
    "Slack search about #{@teammate.person.casual_name} (last #{window_days} days) — #{Time.current.strftime('%Y-%m-%d %H:%M')}"
  end

  def search_notice(search)
    case search.search_status
    when "completed"
      "Found #{search.raw_messages_count} Slack message#{'s' unless search.raw_messages_count == 1}."
    when "failed"
      "Search finished with an error: #{search.search_error}"
    else
      "Slack search saved."
    end
  end
end
