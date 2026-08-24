class Organizations::GetShitDoneController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  before_action :set_teammate
  after_action :bust_header_si_pending_count_cache, only: :something_interesting

  def show
    authorize @teammate, :view_check_ins?

    # Load all pending items using centralized service
    query_service = GetShitDoneQueryService.new(teammate: @teammate)
    @observable_moments = query_service.observable_moments
    @pending_acknowledgement_queue = query_service.pending_acknowledgement_queue
    @pending_acknowledgement_count = @pending_acknowledgement_queue.count
    @observation_drafts = query_service.observation_drafts
    @silent_observations = query_service.silent_observations
    @feedback_expectation_mismatches = query_service.feedback_expectation_mismatches
    @goals_needing_check_in = query_service.goals_needing_check_in
    @check_ins_awaiting_input = query_service.check_ins_awaiting_input
    @total_pending = query_service.total_pending_count
    @something_interesting_count = SomethingInterestingQueryService.new(
      teammate: @teammate,
      since: something_interesting_baseline
    ).total_count
  end

  def something_interesting
    authorize @teammate, :view_check_ins?

    @last_visited_at = something_interesting_last_visited_at
    baseline = something_interesting_baseline
    @since = parsed_since_param || baseline

    query_service = SomethingInterestingQueryService.new(teammate: @teammate, since: @since)
    @goals_by_those_i_serve = query_service.goals_updated_by_those_i_serve
    @goals_on_my_teams = query_service.goals_updated_on_my_teams
    @assignments_updated = query_service.assignments_updated
    @abilities_updated = query_service.abilities_updated
    @observations_about_those_i_serve = query_service.observations_about_those_i_serve
    @observations_about_me = query_service.observations_about_me
    @observation_comments = query_service.observation_comments

    # The tab pill is always "since last visit", independent of the since filter on the page.
    @something_interesting_count =
      if @since == baseline
        query_service.total_count
      else
        SomethingInterestingQueryService.new(teammate: @teammate, since: baseline).total_count
      end
  end

  private

  def something_interesting_last_visited_at
    SomethingInterestingQueryService.last_visited_at(@teammate)
  end

  def something_interesting_baseline
    SomethingInterestingQueryService.baseline(@teammate)
  end

  def bust_header_si_pending_count_cache
    SomethingInterestingQueryService.bust_header_pending_count_cache!(@teammate)
  end

  def parsed_since_param
    return nil if params[:since].blank?

    Date.parse(params[:since]).beginning_of_day
  rescue ArgumentError, TypeError
    nil
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access the dashboard.'
    end
  end

  def set_teammate
    @teammate = current_company_teammate
  end
end
