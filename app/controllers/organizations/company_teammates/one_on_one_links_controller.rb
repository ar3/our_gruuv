class Organizations::CompanyTeammates::OneOnOneLinksController < Organizations::OrganizationNamespaceBaseController
  include Organizations::ObservationsInvolvingTeammateCount
  include Organizations::AssignsViewableTeammates
  include Organizations::OneOnOneExternalProjectSync

  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_one_on_one_link
  before_action :assign_viewable_teammates_for_one_on_one, only: %i[show create update]
  before_action :assign_managers_view_card_for_teammate, only: %i[show create update]

  def show
    authorize @one_on_one_link
    @person = @teammate.person
    load_external_project_cache_for_hub
    load_one_on_one_hub_data
    
    # Check if viewing user has access to the Asana project
    if @source == 'asana' && current_company_teammate&.has_asana_identity? && @one_on_one_link&.asana_project_id
      @has_project_access = check_asana_project_access(@one_on_one_link.asana_project_id)
    else
      @has_project_access = nil
    end
  end

  def create
    authorize @one_on_one_link, :update?
    
    url = one_on_one_link_params[:url]
    
    # Extract project ID if it's an external project link
    if url.present?
      source = ExternalProjectUrlParser.detect_source(url)
      if source == 'asana'
        project_id = extract_asana_project_id(url)
        if project_id
          @one_on_one_link.deep_integration_config ||= {}
          @one_on_one_link.deep_integration_config['asana_project_id'] = project_id
        end
      end
    end
    
    @one_on_one_link.assign_attributes(one_on_one_link_params)
    if @one_on_one_link.save
      maybe_enqueue_asana_sync_after_save!
      redirect_to one_on_one_hub_path(anchor: asana_sync_redirect_anchor), notice: '1:1 link created successfully.'
    else
      @person = @teammate.person
      load_external_project_cache_for_hub
      load_one_on_one_hub_data
      render :show, status: :unprocessable_entity
    end
  end

  def update
    authorize @one_on_one_link
    
    url = one_on_one_link_params[:url]
    
    # Extract project ID if it's an external project link
    if url.present?
      source = ExternalProjectUrlParser.detect_source(url)
      if source == 'asana'
        project_id = extract_asana_project_id(url)
        if project_id
          @one_on_one_link.deep_integration_config ||= {}
          @one_on_one_link.deep_integration_config['asana_project_id'] = project_id
        end
      end
    end
    
    @one_on_one_link.assign_attributes(one_on_one_link_params)
    if @one_on_one_link.save
      maybe_enqueue_asana_sync_after_save!
      redirect_to one_on_one_hub_path(anchor: asana_sync_redirect_anchor), notice: '1:1 link updated successfully.'
    else
      @person = @teammate.person
      load_external_project_cache_for_hub
      load_one_on_one_hub_data
      render :show, status: :unprocessable_entity
    end
  end

  def sync
    authorize @one_on_one_link, :update?

    source = params[:source] || @one_on_one_link.external_project_source
    unless source.present?
      redirect_to one_on_one_hub_path(anchor: "sync"), alert: "No project source detected."
      return
    end

    enqueue_one_on_one_asana_sync!(source: source)
  end

  def sync_status
    authorize @one_on_one_link, :update?

    source = params[:source] || @one_on_one_link.external_project_source
    cache = ExternalProjectCache.find_by(cacheable: @one_on_one_link, source: source) if source.present?
    if cache.nil?
      return render json: { status: "none", elapsed_seconds: 0, stale: false, slow: false }
    end

    render json: external_project_sync_status_json(cache)
  end

  def associate_project
    authorize @one_on_one_link, :update?
    # Future: Implement project association logic
    redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), notice: 'Project association not yet implemented.'
  end

  def disassociate_project
    authorize @one_on_one_link, :update?
    
    source = params[:source] || @one_on_one_link.external_project_source
    return redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), alert: 'No project source detected.' unless source.present?
    
    cache = @one_on_one_link.external_project_cache_for(source)
    if cache
      cache.destroy
      redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), notice: 'Project cache removed successfully.'
    else
      redirect_to organization_company_teammate_one_on_one_link_path(organization, @teammate), alert: 'No cache found to remove.'
    end
  end

  private

  def assign_viewable_teammates_for_one_on_one
    return unless @teammate

    assign_viewable_teammates_context!(selected_teammate: @teammate)
  end

  def assign_managers_view_card_for_teammate
    return unless @teammate

    @filtered_and_paginated_teammates = [@teammate]
    @check_in_health_caches_by_teammate = CheckInHealthCache
      .where(teammate_id: @teammate.id, organization_id: organization.id)
      .index_by(&:teammate_id)
    @managers_view_observations_involving_counts_by_teammate_id =
      if Pundit.policy(pundit_user, company).view_observations?
        { @teammate.id => observations_involving_teammate_total_count(@teammate) }
      else
        {}
      end
  end

  def load_one_on_one_hub_data
    load_execute_metrics
    load_evolve_metrics
    load_teammate_growth_for_one_on_one_hub
    load_goals_confidence_chart_data
    load_one_thing_priority_carousel
  end

  def load_teammate_growth_for_one_on_one_hub
    @can_run_teammate_growth = CompanyTeammatePolicy.new(pundit_user, @teammate).run_teammate_growth?
    return unless @can_run_teammate_growth

    @teammate_growth_maap_run = MaapAgentRun.find_by(
      subject: @teammate,
      agent_kind: MaapAgentRun::AGENT_KIND_TEAMMATE_GROWTH
    )
  end

  def load_one_thing_priority_carousel
    @priority_carousel = OneOnOne::PriorityCarouselBuilder.call(
      organization: organization,
      teammate: @teammate,
      one_on_one_link: @one_on_one_link,
      viewing_company_teammate: current_company_teammate
    )
  end

  def load_execute_metrics
    @all_goals_for_teammate = Goal.where(owner: @teammate, deleted_at: nil)
      .includes(:goal_check_ins)
      .order(created_at: :desc)
    @active_goals = @all_goals_for_teammate.select { |goal| goal.completed_at.nil? && goal.started_at.present? }
    @draft_goals_count = @all_goals_for_teammate.count { |goal| goal.started_at.nil? && goal.completed_at.nil? }

    active_goal_associations = GoalAssociation
      .joins(:goal)
      .where(goals: { owner_type: "CompanyTeammate", owner_id: @teammate.id, completed_at: nil, deleted_at: nil })
      .pluck(:associable_type, :associable_id)
    active_goal_association_lookup = active_goal_associations.each_with_object({}) do |(type, id), lookup|
      lookup[[type, id]] = true
    end

    assignment_check_ins = AssignmentCheckIn
      .where(company_teammate: @teammate)
      .closed
      .order(official_check_in_completed_at: :desc)
    latest_assignment_check_ins = assignment_check_ins.index_by(&:assignment_id)
    @assignment_missing_goal_items = latest_assignment_check_ins.values.select do |check_in|
      check_in.official_rating == "working_to_meet" &&
        !active_goal_association_lookup[["Assignment", check_in.assignment_id]]
    end

    aspiration_check_ins = AspirationCheckIn
      .where(company_teammate: @teammate)
      .closed
      .order(official_check_in_completed_at: :desc)
    latest_aspiration_check_ins = aspiration_check_ins.index_by(&:aspiration_id)
    @aspiration_missing_goal_items = latest_aspiration_check_ins.values.select do |check_in|
      check_in.official_rating == "working_to_meet" &&
        !active_goal_association_lookup[["Aspiration", check_in.aspiration_id]]
    end

    required_ability_rows = required_abilities_for_current_position(@teammate)
    @ability_missing_goal_items = required_ability_rows.each_with_object([]) do |row, memo|
      next unless row[:required_level].to_i > row[:earned_level].to_i
      next if active_goal_association_lookup[["Ability", row[:ability].id]]
      memo << row
    end

    @missing_goal_total_count = @assignment_missing_goal_items.count +
      @aspiration_missing_goal_items.count +
      @ability_missing_goal_items.count

    @active_goals_needing_check_in_count = @active_goals.count do |goal|
      latest_check_in = goal.goal_check_ins.max_by(&:check_in_week_start)
      latest_check_in.nil? || latest_check_in.check_in_week_start < 2.weeks.ago.to_date.beginning_of_week(:monday)
    end

    @completed_goals = @all_goals_for_teammate.select { |goal| goal.completed_at.present? }
    @last_goal_completed_at = @completed_goals.map(&:completed_at).compact.max

    outcome_counts = @all_goals_for_teammate.each_with_object({ on_time: 0, late: 0, missed: 0 }) do |goal, counts|
      target_date = goal.calculated_target_date
      next if target_date.blank?

      if goal.completed_at.present?
        if goal.completed_at.to_date <= target_date
          counts[:on_time] += 1
        else
          counts[:late] += 1
        end
      elsif goal.started_at.present? && target_date < Date.current
        counts[:missed] += 1
      end
    end
    total_outcomes = outcome_counts.values.sum
    @goal_outcome_counts = outcome_counts
    @goal_outcome_rates = if total_outcomes.positive?
      {
        on_time: ((outcome_counts[:on_time] * 100.0) / total_outcomes).round(1),
        late: ((outcome_counts[:late] * 100.0) / total_outcomes).round(1),
        missed: ((outcome_counts[:missed] * 100.0) / total_outcomes).round(1)
      }
    else
      { on_time: 0.0, late: 0.0, missed: 0.0 }
    end
  end

  def load_evolve_metrics
    thirty_days_ago = 30.days.ago
    @observations_given_30d_count = Observation
      .where(company: organization, observer: @teammate.person)
      .where("observed_at >= ?", thirty_days_ago)
      .where.not(published_at: nil)
      .where(deleted_at: nil)
      .count
    @observations_received_30d_count = Observation
      .joins(:observees)
      .where(company: organization)
      .where(observees: { teammate_id: @teammate.id })
      .where("observed_at >= ?", thirty_days_ago)
      .where.not(published_at: nil)
      .where(deleted_at: nil)
      .count

    @upcoming_check_ins = upcoming_check_in_rows
    @abilities_gap_rows = required_abilities_for_current_position(@teammate).select do |row|
      row[:required_level].to_i > row[:earned_level].to_i
    end
    @observations_involving_url = if Pundit.policy(pundit_user, company).view_observations?
                                  organization_observations_path(organization, involving_teammate_id: @teammate.id)
                                end
  end

  def load_goals_confidence_chart_data
    ninety_days_ago = 90.days.ago.to_date
    goals = Goal
      .where(owner: @teammate, deleted_at: nil)
      .where.not(started_at: nil)
      .includes(:goal_check_ins)
      .order(:title)
    series = goals.each_with_object([]) do |goal, memo|
      scoped_check_ins = goal.goal_check_ins
        .select { |check_in| check_in.confidence_percentage.present? && check_in.check_in_week_start.present? }
        .sort_by(&:check_in_week_start)
      next if scoped_check_ins.empty?

      earliest_for_goal = scoped_check_ins.first.check_in_week_start
      start_date = [ninety_days_ago, earliest_for_goal].max
      points = scoped_check_ins
        .select { |check_in| check_in.check_in_week_start >= start_date }
        .map { |check_in| [check_in.check_in_week_start.to_time.to_i * 1000, check_in.confidence_percentage.to_f] }
      next if points.empty?

      memo << {
        name: goal.title,
        data: points
      }
    end
    @goals_confidence_series = series
  end

  def required_abilities_for_current_position(teammate)
    position = teammate.active_employment_tenure&.position
    return [] unless position

    required_levels = Hash.new(0)
    position.required_assignments.includes(assignment: { assignment_abilities: :ability }).each do |position_assignment|
      position_assignment.assignment.assignment_abilities.each do |assignment_ability|
        ability_id = assignment_ability.ability_id
        required_levels[ability_id] = [required_levels[ability_id], assignment_ability.milestone_level.to_i].max
      end
    end
    position.position_abilities.includes(:ability).each do |position_ability|
      ability_id = position_ability.ability_id
      required_levels[ability_id] = [required_levels[ability_id], position_ability.milestone_level.to_i].max
    end
    return [] if required_levels.empty?

    abilities_by_id = Ability.where(id: required_levels.keys).index_by(&:id)
    earned_levels = TeammateMilestone
      .where(company_teammate: teammate, ability_id: required_levels.keys)
      .group(:ability_id)
      .maximum(:milestone_level)
    required_levels.each_with_object([]) do |(ability_id, required_level), rows|
      ability = abilities_by_id[ability_id]
      next unless ability
      rows << {
        ability: ability,
        required_level: required_level,
        earned_level: earned_levels[ability_id].to_i
      }
    end
  end

  def upcoming_check_in_rows
    position = @teammate.active_employment_tenure&.position
    rows = []

    position_latest = PositionCheckIn.latest_finalized_for(@teammate)
    rows << build_due_row(
      "Position",
      position&.display_name || "Current position",
      position_latest,
      url: position_check_in_organization_teammate_path(organization, @teammate)
    )

    if position
      assignment_ids = position.required_assignments.pluck(:assignment_id)
      assignments = Assignment.where(id: assignment_ids)
      assignments.each do |assignment|
        latest = AssignmentCheckIn.latest_finalized_for(@teammate, assignment)
        rows << build_due_row(
          "Assignment",
          assignment.title,
          latest,
          url: organization_teammate_assignment_path(organization, @teammate, assignment)
        )
      end
    end

    Aspiration.within_hierarchy(organization).ordered.each do |aspiration|
      latest = AspirationCheckIn.latest_finalized_for(@teammate, aspiration)
      rows << build_due_row(
        "Aspiration",
        aspiration.name,
        latest,
        url: organization_teammate_aspiration_path(organization, @teammate, aspiration)
      )
    end

    rows.sort_by { |row| row[:due_on] || Date.current }
  end

  def build_due_row(type, name, latest_check_in, url: nil)
    due_on = if latest_check_in&.official_check_in_completed_at
      latest_check_in.official_check_in_completed_at.to_date + (CheckInBehavior::CLARITY_BLURRED_DAYS + 1).days
    end
    {
      type: type,
      name: name,
      url: url,
      due_on: due_on,
      overdue: due_on.blank? || due_on < Date.current
    }
  end

  def asana_sync_redirect_anchor
    @one_on_one_link.external_project_source == "asana" ? "sync" : nil
  end

  def set_teammate
    @teammate = find_organization_teammate!(params[:company_teammate_id])
  end

  def extract_asana_project_id(url)
    AsanaUrlParser.extract_project_id(url)
  end

  def set_one_on_one_link
    if @teammate
      @one_on_one_link = @teammate.one_on_one_link || OneOnOneLink.new(teammate: @teammate)
    else
      @one_on_one_link = nil
    end
  end

  def one_on_one_link_params
    params.require(:one_on_one_link).permit(:url)
  end

  def check_asana_project_access(project_id)
    return false unless current_company_teammate&.has_asana_identity?
    
    service = AsanaService.new(current_company_teammate)
    return false unless service.authenticated?
    
    # Try to fetch the project to check access
    project = service.fetch_project(project_id)
    
    # If project is nil, check if it was a permission error
    # We'll check the sections endpoint which is more reliable for access
    sections_result = service.fetch_project_sections(project_id)
    
    if sections_result[:success]
      true
    elsif sections_result[:error] == 'permission_denied'
      false
    else
      # For other errors (not_found, network_error, etc.), assume no access
      # The actual sync will handle these errors appropriately
      false
    end
  end
end



