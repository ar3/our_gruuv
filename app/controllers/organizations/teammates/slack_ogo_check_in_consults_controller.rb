# frozen_string_literal: true

class Organizations::Teammates::SlackOgoCheckInConsultsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_rateable
  after_action :verify_authorized

  def show
    authorize @teammate.person, :view_check_ins?, policy_class: PersonPolicy
    search = find_search_for_status
    if search.nil?
      render json: idle_payload
      return
    end

    render json: status_payload(search)
  end

  def create
    authorize @teammate.person, :view_check_ins?, policy_class: PersonPolicy
    viewer = current_company_teammate
    unless viewer
      render json: { ok: false, error: "Sign in as a teammate in this organization." }, status: :unprocessable_entity
      return
    end

    mode = params[:mode].presence || "fresh"
    existing =
      if params[:search_id].present?
        PossibleObservationSlackSearch
          .where(organization: organization, subject_company_teammate: @teammate)
          .find_by(id: params[:search_id])
      else
        CheckIns::SlackOgoConsult::RecentSearchFinder.call(
          viewer: viewer,
          subject_teammate: @teammate
        )
      end

    result = CheckIns::SlackOgoConsult::Starter.call(
      organization: organization,
      viewer: viewer,
      subject_teammate: @teammate,
      mode: mode,
      existing_search: existing
    )

    if result.needs_slack_oauth
      render json: {
        ok: false,
        needs_slack_oauth: true,
        oauth_url: slack_oauth_url,
        error: result.error
      }, status: :unprocessable_entity
      return
    end

    unless result.ok?
      render json: { ok: false, error: result.error }, status: :unprocessable_entity
      return
    end

    render json: status_payload(result.search).merge(ok: true)
  end

  private

  def set_teammate
    @teammate = find_organization_teammate!(params[:teammate_id])
  end

  def set_rateable
    type = params[:rateable_type].to_s
    unless CheckIns::SlackOgoConsult.rateable_type_valid?(type)
      head :bad_request
      return
    end

    @rateable_type = type
    @rateable = type.constantize.where(company: organization).find(params[:rateable_id])
    @object_name =
      case type
      when "Assignment" then @rateable.title
      else @rateable.name
      end
  end

  def find_search_for_status
    if params[:search_id].present?
      return PossibleObservationSlackSearch
             .where(organization: organization, subject_company_teammate: @teammate)
             .find_by(id: params[:search_id])
    end

    viewer = current_company_teammate
    return nil unless viewer

    CheckIns::SlackOgoConsult::RecentSearchFinder.call(
      viewer: viewer,
      subject_teammate: @teammate
    )
  end

  def status_payload(search)
    CheckIns::SlackOgoConsult::StatusBuilder.call(
      search: search,
      rateable_type: @rateable_type,
      rateable_id: @rateable.id,
      organization: organization,
      subject_teammate: @teammate,
      object_name: @object_name,
      helpers: self
    )
  end

  def idle_payload
    {
      phase: "idle",
      search_id: nil,
      object_matches: [],
      other_count: 0,
      polling: false,
      can_refresh_search: false,
      can_stronger_model: false
    }
  end

  def slack_oauth_url
    organization_company_teammate_slack_search_oauth_authorize_path(
      organization,
      current_company_teammate,
      source: "checkInConsult",
      return_to: return_to_check_in_url
    )
  end

  def return_to_check_in_url
    case @rateable_type
    when "Assignment"
      organization_teammate_assignment_url(organization, @teammate, @rateable)
    when "Aspiration"
      organization_teammate_aspiration_url(organization, @teammate, @rateable)
    when "Ability"
      organization_teammate_ability_url(organization, @teammate, @rateable)
    end
  end
end
