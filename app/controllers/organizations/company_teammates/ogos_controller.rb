# frozen_string_literal: true

class Organizations::CompanyTeammates::OgosController < Organizations::OrganizationNamespaceBaseController
  include Organizations::AssignsViewableTeammates
  include Organizations::ObservationsInvolvingTeammateCount

  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_one_on_one_link
  before_action :assign_viewable_teammates_context
  after_action :verify_authorized

  def about
    load_page(active_tab: :about)
    render :about
  end

  def from
    load_page(active_tab: :from)
    render :from
  end

  def feedback_requests
    load_page(active_tab: :feedback_requests)
    render :feedback_requests
  end

  def source_from_slack
    load_page(active_tab: :source_from_slack)
    @prior_slack_searches = PossibleObservationSlackSearch
                            .for_subject(@teammate)
                            .where(organization: organization)
                            .recent_first
                            .includes(:message_batches, creator_company_teammate: :person)
                            .limit(25)
    render :source_from_slack
  end

  private

  def load_page(active_tab:)
    authorize @one_on_one_link, :ogos?

    @person = @teammate.person
    @active_tab = active_tab
    @casual_name = @person.casual_name

    page_data = TeammateOgos::PageLoader.call(
      organization: organization,
      teammate: @teammate,
      current_person: current_person,
      viewing_company_teammate: current_company_teammate,
      one_on_one_link: @one_on_one_link,
      active_tab: active_tab
    )

    @observation_health = page_data[:observation_health]
    @about_counts = page_data[:about_counts]
    @from_counts = page_data[:from_counts]
    @observations_involving_url = page_data[:observations_involving_url]
    @observations = page_data[:observations]
    @feedback_requests = page_data[:feedback_requests]
    @feedback_request_rows = page_data[:feedback_request_rows]
    @open_respondent_requests = page_data[:open_respondent_requests]

    preload_rateables(@observations)
  end

  def assign_viewable_teammates_context
    return unless @teammate

    assign_viewable_teammates_context!(selected_teammate: @teammate)
  end

  def set_teammate
    @teammate = find_organization_teammate!(params[:id])
  end

  def set_one_on_one_link
    @one_on_one_link = @teammate&.one_on_one_link || OneOnOneLink.new(teammate: @teammate)
  end

  def preload_rateables(observations)
    rating_ids_by_type = observations.flat_map(&:observation_ratings).group_by(&:rateable_type)

    rating_ids_by_type.each do |rateable_type, ratings|
      ids = ratings.map(&:rateable_id).uniq
      next if ids.empty?

      case rateable_type
      when "Assignment"
        Assignment.where(id: ids).load
      when "Ability"
        Ability.where(id: ids).load
      when "Aspiration"
        Aspiration.where(id: ids).load
      end
    end
  end
end
